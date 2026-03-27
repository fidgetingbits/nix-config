#!/usr/bin/env bash
#
# NOTE: See ./default.nix:19 for packaging
#
# Overview:
#   enter the synology as borg user
#   plant an ssh key
#   connect to oath and have it directly rsync to moth
#
# TODO:
#   - [ ] This needs to to implement 'collectionsFolder' logic that mirror-backups is
#         using, so we can re-add --delete
#
# FIXME: We may need to add some synology-specific functionality to prevent
# auto-updates auto-reboot during sync?
#
# FIXME: Rework to deduplicate as much as possible with long-rsync/mirror-backups

STARTED=$(date "+%Y-%m-%d %H:%M:%S")
KEY_FILE=/root/.ssh/id_borg
SOURCE_HOST=oath
SOURCE_FOLDER="/volume1/backups/"
SOURCE_USER=borg

SOURCE="$SOURCE_USER@$SOURCE_HOST"

DEST_USER=borg
DEST_HOST=moth
DEST_FOLDER="/mnt/storage/mirror/aa/"

# Reduce the noise of warnings, don't prompt for yubikey when key has been planted, etc
# FIXME: We should be able to remove some of these as they were more relevant
# to long-rsync where we don't know if we already have the keys
declare -a sshArgs=(
    "-o" "PreferredAuthentications=publickey"
    "-o" "VisualHostKey=no"
    "-o" "LogLevel=ERROR"
    "-o" "StrictHostKeyChecking=no"
    "-o" "port=${SSH_PORT:-22}")

function runSshI {
    # shellcheck disable=SC2029
    ssh "${sshArgs[@]}" -o IdentitiesOnly=Yes -i "$KEY_FILE" "$@"
}

function runScp {
    scp -O "${sshArgs[@]}" -i "$KEY_FILE" -o IdentitiesOnly=yes "$@"
}

function cleanup {
    runSshI "rm id_mirror rsync.sh"
    rm -rf "$tmp_dir"
}

TOOL=$(basename "$0")
LOCK=$(basename "${0%.*}")

# Don't allow this script to be run at the same time
exec {LOCKFD}>/var/lock/"$LOCK".lock
if ! flock -n "$LOCKFD"; then
    echo "Another copy of $TOOL is running; exiting"
    exit 0
fi

runScp "$KEY_FILE" "$SOURCE:id_mirror"
tmp_dir=$(mktemp -d)
trap cleanup EXIT

runSshI "$SOURCE" "chmod 600 id_mirror"

RSYNC_PATH="/run/current-system/sw/bin/rsync" # /bin/rsync is what's on the synology, but allow override
FILENAME="rsync.sh"
cat >>"$tmp_dir"/rsync.sh <<EOF
exec {LOCKFD}>~/"$LOCK".lock
if ! flock -n $LOCKFD; then
    echo "Another copy of $TOOL is running; exiting"
    exit 0
fi

# FIXME: Remove --remote-option=--log-file=/tmp/rlog after debugging
# FIXME: Fix this messing up the permissions of the destination folder (becomes 711)
# Switch to --info=progress2 probably
# Add the chmod to match the other script?
rsync -aHSP \
    --stats \
    --dry-run \
    --rsync-path=$RSYNC_PATH \
    --remote-option=--log-file=/tmp/rlog \
    --chmod=Dg+srwx,Fg+rw,o-rwx \
    -e "ssh ${sshArgs[@]} -i id_mirror -o IdentitiesOnly=yes -o BatchMode=yes" \
    "$SOURCE_FOLDER" \
    "$DEST_USER@$DEST_HOST:$DEST_FOLDER"
EOF

runScp "$tmp_dir/$FILENAME" "$SOURCE:$FILENAME"
# Run the rsync command on the source host in a loop until it completes
SYNC_LOOP=$(
    cat <<EOF
    until ssh ${sshArgs[@]} -i "$KEY_FILE" -o IdentitiesOnly=yes "$SOURCE" \
    "sh < $FILENAME"; \
    do
        echo "Connection lost, retrying..."
        sleep 10 # Maybe to cool down disks if connection loss was related? Because of moth heat issues...
    done
EOF
)

echo "Running inhibited rsync loop"
sudo systemd-inhibit --why="Mirroring oath backups to moth" \
    --who="Backup Mirror" \
    --mode=block bash -c "$SYNC_LOOP"

ENDED=$(date "+%Y-%m-%d %H:%M:%S")

# RECIPIENTS and DELIVERER come from nix package
msmtp -t <<EOF
To: ${RECIPIENTS:-}
From: ${DELIVERER:-}
Subject: [$(hostname): mirror-oath]: Copy from $SOURCE_HOST to $DEST_HOST completed

Copy from $SOURCE_HOST to $DEST_HOST completed

Ran from $STARTED until $ENDED
EOF

echo "Copy from $SOURCE_HOST to $DEST_HOST completed"
