# shellcheck disable=SC2148
# NOTE: See ./default.nix:19 for packaging
#
# Overview:
#   enter the synology as borg user
#   temporarily plant an ssh key that can be used to copy to moth
#   connect to synology and have it directly rsync each sub folder to moth
#
# FIXME: Rework to deduplicate as much as possible with long-rsync/mirror-backups

# set -x

STARTED=$(date "+%Y-%m-%d %H:%M:%S")
KEY_FILE=/root/.ssh/id_borg
SOURCE_HOST=oath
SOURCE_FOLDER="/volume1/backups/"
SOURCE_USER=borg

SOURCE="$SOURCE_USER@$SOURCE_HOST"

DEST_USER=borg
DEST_HOST=moth
DEST_FOLDER="/mnt/storage/mirror/aa/"

SSH_BIN=$(which ssh)

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
    runSshI "$SOURCE" "rm id_mirror rsync.sh"
    rm -rf "$tmp_dir"
}

TOOL=$(basename "$0")
LOCK=$(basename "${0%.*}")

if [ $UID != 0 ]; then
    echo "ERROR: Script needs to access root-stored borg identity"
    exit 1
fi

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

# /bin/rsync is what's on the synology, but allow override
RSYNC_PATH="/run/current-system/sw/bin/rsync"
FILENAME="rsync.sh"
cat >>"$tmp_dir"/rsync.sh <<EOF
set -x
exec {LOCKFD}>~/"$LOCK".lock
if ! flock -n $LOCKFD; then
    echo "Another copy of $TOOL is running; exiting"
    exit 0
fi

# This syncs to a destination folder that may already have contents mirrored/synced
# from other servers. This means in order to use --delete, we must iterate over each
# sub directory

for sub in \$(find "$SOURCE_FOLDER" -mindepth 1 -maxdepth 1 -type d -printf "%P\n"); do
    echo "Processing collection subfolder: \$sub"

    # e.g., /mnt/storage/mirror/aa/ossa
    DEST_SUBFOLDER="${DEST_FOLDER%/}/\$sub"

    # Create the folder if it doesn't exist already
    ssh ${sshArgs[*]} \
        -i id_mirror -o IdentitiesOnly=yes -o BatchMode=yes \
        "$DEST_USER@$DEST_HOST" \
        "mkdir -p \$DEST_SUBFOLDER 2>/dev/null || true"

    # FIXME: Fix this messing up the permissions of the destination folder (becomes 711)
    # We will want to add --delete eventually
    #
    # Debug:
    # --remote-option=--log-file=/tmp/rlog
    # --dry-run
    echo "Mirroring \$sub"
    rsync -aHSP \
        --stats \
        --rsync-path=$RSYNC_PATH \
        --delete \
        --chmod=Dg+srwx,Fg+rw,o-rwx \
        -e "ssh ${sshArgs[*]} -i id_mirror -o IdentitiesOnly=yes -o BatchMode=yes" \
        "$SOURCE_FOLDER/\$sub/" \
        "$DEST_USER@$DEST_HOST:\$DEST_SUBFOLDER"
done
EOF

runScp "$tmp_dir/$FILENAME" "$SOURCE:$FILENAME"
# Run the rsync command on the source host in a loop until it completes
# FIXME: This might not always fail in a way we want it to repeat
until "$SSH_BIN" "${sshArgs[@]}" -i "$KEY_FILE" -o IdentitiesOnly=yes "$SOURCE" \
    "sh < $FILENAME"; do
    echo "Connection lost, retrying..."
    sleep 10 # Maybe to cool down disks if connection loss was related? Because of moth historical heat issues...
done

ENDED=$(date "+%Y-%m-%d %H:%M:%S")

# RECIPIENTS and DELIVERER come from nix package
msmtp -t <<EOF
To: ${RECIPIENTS:-}
From: ${DELIVERER:-}
Subject: [$(hostname): mirror-oath]: Mirroring backups from $SOURCE_HOST to $DEST_HOST completed

Copy from $SOURCE_HOST to $DEST_HOST completed

Ran from $STARTED until $ENDED
EOF

echo "Copy from $SOURCE_HOST to $DEST_HOST completed"
