#!/usr/bin/env bash
#
# Usage: ./long-rsync.sh <source_ip> <source_folder> <dest_ip> <dest_folder>
#
# This is a script to help with long copies that you want to be running in the
# background. It should be run inside a zellij session from whatever host won't
# be rebooted during the process.
#
# At the moment this is ONLY tested on two synology NAS that need to copy between each other.
# It also partially requires manual authentication to the target servers in order to get going.

set -eou pipefail
# FIXME:This should add parse_args or similar to add debug
set -x

if [ $# -lt 4 ]; then
    echo "Usage: $0 <source_ip> <source_folder> <dest_ip> <dest_folder>"
    exit 1
fi

SOURCE_HOST="${1}"
SOURCE_FOLDER="${2}"
# FIXME:This default user should come from nix probably?
SOURCE_USER="${SOURCE_USER:-aa}"

DEST_HOST="${3}"
DEST_FOLDER="${4}"
DEST_USER="${DEST_USER:-aa}"

# track if we added an entry to authorized_keys
source_key_added=0
dest_key_added=0

KEY_FILE="migration.key"

# Reduce the noise of warnings, don't prompt for yubikey when key has been planted, etc
declare -a sshArgs=(
    "-o" "PreferredAuthentications=publickey"
    "-o" "VisualHostKey=no"
    "-o" "LogLevel=ERROR"
    "-o" "StrictHostKeyChecking=no"
    "-o" "port=${SSH_PORT:-22}")

# Run ssh that will prompt for yubikey for temporary key dropping
function runSsh {
    # shellcheck disable=SC2029
    ssh "${sshArgs[@]}" "$@"
}

# Run ssh with the planted key that will use passwordless auth
function runSshI {
    # shellcheck disable=SC2029
    ssh "${sshArgs[@]}" -o IdentitiesOnly=Yes -i "$PWD/$KEY_FILE" "$@"
}

# Run scp with the planted key that will use passwordless auth
function runScp {
    # -O is needed because of synology
    scp -O "${sshArgs[@]}" -i "$PWD/$KEY_FILE" -o IdentitiesOnly=yes "$@"
}

function cleanup {
    if [ -f "$KEY_FILE" ]; then
        runSshI "$SOURCE_USER@$SOURCE_HOST" sh -- <<EOF
            rm -f "$SOURCE_TMP/$KEY_FILE" || true
EOF
    fi

    if [[ $source_key_added -eq 1 ]]; then
        runSshI "$SOURCE_USER@$SOURCE_HOST" sh -- <<EOF
            sed -i '/long rsync copy/,+1d' ~/.ssh/authorized_keys
EOF
    fi

    if [[ $dest_key_added -eq 1 ]]; then
        runSshI "$DEST_USER@$DEST_HOST" sh -- <<EOF
            sed -i '/long rsync copy/,+1d' ~/.ssh/authorized_keys
EOF
    fi

    # We wait to delete this key locally until we already used it above
    if [ -f "$KEY_FILE" ]; then
        rm -f "$PWD/$KEY_FILE" "$PWD/${KEY_FILE}.pub"
    fi

    rm -rf "$tmp_dir"
}

tmp_dir=$(mktemp -d)
echo "INFO: Using $tmp_dir for $(hostname) storage"
SOURCE_TMP=$(runSsh -o IdentitiesOnly=no "$SOURCE_USER@$SOURCE_HOST" "mktemp -d")
echo "INFO: Using $SOURCE_TMP for $SOURCE_HOST storage"

trap cleanup EXIT

if [ ! -f "$KEY_FILE" ]; then
    ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -q

    function add_authorized_key {
        local pub_key
        pub_key=$(cat "${KEY_FILE}.pub")
        runSsh "$1" sh -- <<EOF
            echo "# $0: long rsync copy on $(hostname) from $SOURCE_HOST -> $DEST_HOST -- $(date +%Y%m%d%H%M%S)" >> ~/.ssh/authorized_keys
            echo $pub_key >> ~/.ssh/authorized_keys
EOF
    }

    add_authorized_key "$SOURCE_USER@$SOURCE_HOST"
    export source_key_added=1
    add_authorized_key "$DEST_USER@$DEST_HOST"
    export dest_key_added=1
fi

runScp "$PWD/$KEY_FILE" "$SOURCE_USER@$SOURCE_HOST:$SOURCE_TMP/$KEY_FILE"
runSshI "$SOURCE_USER@$SOURCE_HOST" "chmod 600 $SOURCE_TMP/$KEY_FILE"

# FIXME:This --rsync-path may need to get fixed up depending on the target? This is specific to synology atm
# FIXME:Remove -v from rsync eventually, likely add -H, --stats, -S, maybe chmod since the uid might differ?
FILENAME="rsync.sh"
cat >>"$tmp_dir"/rsync.sh <<EOF
set -x
rsync -avP --rsync-path=/bin/rsync -e "ssh -v ${sshArgs[@]} -i $SOURCE_TMP/$KEY_FILE -o IdentitiesOnly=yes -o BatchMode=yes" "$SOURCE_FOLDER" "$DEST_USER@$DEST_HOST:$DEST_FOLDER"
EOF

runScp "$tmp_dir/$FILENAME" "$SOURCE_USER@$SOURCE_HOST:$SOURCE_TMP/$FILENAME"
runSshI "$SOURCE_USER@$SOURCE_HOST" "chmod +x $SOURCE_TMP/$FILENAME"

# Run the rsync command on the source host in a loop until it completes. Sleep 10 is used
# to give the disks a chance to cool down
# FIXME: probably want some sanity escape hatch in case their is a legit error and not a connection loss
# NOTE:target /tmp may be noexec, so be sure to use sh <
SYNC_LOOP=$(
    cat <<EOF
    until ssh ${sshArgs[@]} -i "$PWD/$KEY_FILE" -o IdentitiesOnly=yes "$SOURCE_USER@$SOURCE_HOST" \
    "sh < $SOURCE_TMP/$FILENAME"; \
    do
        echo "Connection lost, retrying..."
        sleep 10
    done
EOF
)

# FIXME: re-enable systemd-inhibit
#systemd-inhibit --why="Large Data Migration" --who="Rsync Task" --mode=block \
bash -c "$SYNC_LOOP"

# RECIPIENTS and DELIVERER come from nix package
msmtp -t <<EOF
To: ${RECIPIENTS:-}
From: ${DELIVERER:-}
Subject: [$(hostname)}: rsync]: Copy from $SOURCE_HOST to $DEST_HOST completed

Copy from $SOURCE_HOST to $DEST_HOST completed
EOF
