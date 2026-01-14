#!/usr/bin/env bash
#
# Usage: ./long-rsync.sh <source_ip> <source_folder> <dest_ip> <dest_folder>
#
# This is a script to help with long copies that you want to be running in the
# background. It should be run inside a zellij session from whatever host won't
# be rebooted during the process.

trap cleanup EXIT

set -eou pipefail
set -x

SSH_PORT=10022
SOURCE_HOST="${1}"
SOURCE_FOLDER="${2}"
SOURCE_USER=aa

DEST_HOST="${3}"
DEST_FOLDER="${4}"
DEST_USER=aa

# track if we added an entry to authorized_keys
source_key_added=0
dest_key_added=0

KEY_FILE="migration.key"

# Reduce the noise of warnings, don't prompt for yubikey when testing, etc
declare -a sshArgs=("-o" "IdentitiesOnly=yes"
    "-o" "VisualHostKey=no"
    "-o" "LogLevel=ERROR"
    "-o" "StrictHostKeyChecking=no"
    "-o" "port=$SSH_PORT")

function runSsh {
    # shellcheck disable=SC2029
    ssh "${sshArgs[@]}" "$@"
}

function runScp {
    # -O is needed because of synology
    scp -O "${sshArgs[@]}" "$@"
}

function cleanup {
    if [ -f "$KEY_FILE" ]; then
        runSsh -i "$KEY_FILE" "$SOURCE_USER@$SOURCE_HOST" sh -- <<EOF
            rm -f "/volume1/shared/$KEY_FILE" || true
EOF
        rm -f "$PWD/$KEY_FILE" "$PWD/${KEY_FILE}.pub"
    fi

    if [[ $source_key_added -eq 1 ]]; then
        runSsh "$SOURCE_USER@$SOURCE_HOST" sh -- <<EOF
            sed -n '/long rsync copy/{n;d;};p' ~/.ssh/authorized_keys
EOF
    fi

    if [[ $dest_key_added -eq 1 ]]; then
        runSsh "$SOURCE_USER@$SOURCE_HOST" sh -- <<EOF
            sed -n '/long rsync copy/{n;d;};p' ~/.ssh/authorized_keys
EOF
    fi
}

tmp_dir=$(mktemp -d)
echo "INFO: Using $tmp_dir for $(hostname) storage"
SOURCE_TMP=runSsh mktemp -d
echo "INFO: Using $SOURCE_TMP for $SOURCE_HOST storage"

if [ ! -f "$KEY_FILE" ]; then
    ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -q

    function add_authorized_key {
        local pub_key
        pub_key=$(cat "${KEY_FILE}.pub")
        runSsh "$1" sh -- <<EOF
            echo "# $0: long rsync copy on $(hostname) from $SOURCE_HOST -> $DEST_HOST" >> ~/.ssh/authorized_keys
            echo $pub_key >> ~/.ssh/authorized_keys
EOF
    }

    add_authorized_key "$SOURCE_USER@$SOURCE_HOST"
    source_key_added=1
    add_authorized_key "$DEST_USER@$DEST_HOST"
    dest_key_added=1

    # Copy the key file to source, since it will also use it to copy to dest
    runScp -i "$PWD/$KEY_FILE" "$SOURCE_TMP/$KEY_FILE"
fi

runScp -i "$PWD/$KEY_FILE" "$PWD/$KEY_FILE" "$SOURCE_USER@$SOURCE_HOST:$SOURCE_TMP/$KEY_FILE"
runSsh -i "$PWD/$KEY_FILE" "$SOURCE_USER@$SOURCE_HOST" "chmod 600 $SOURCE_TMP/$KEY_FILE"

FILENAME="rsync.sh"
cat >>"$tmp_dir"/rsync.sh <<EOF
rsync -avP --rsync-path=/bin/rsync -e "ssh -v $SSH_ARGS -i $SOURCE_TMP/$KEY_FILE -o BatchMode=yes" "$SOURCE_FOLDER" "$DEST_USER@$DEST_HOST:$DEST_FOLDER"
EOF

runScp -i "$PWD/$KEY_FILE" "$FILENAME" "$SOURCE_USER@$SOURCE_HOST:$SOURCE_TMP/$FILENAME"

#systemd-inhibit --why="Large Data Migration" --who="Rsync Task" --mode=block \
bash -c <<EOF
until ssh "$SSH_ARGS" -i "$PWD/$KEY_FILE" "$SOURCE_USER@$SOURCE_HOST" \
    "$tmp_dir/$FILENAME"; \
    do
        echo "Connection lost, retrying..."
    sleep 10
done
EOF

msmtp -t <<EOF
To: $RECIPIENTS
From: $DELIVERER
Subject: [$(hostname)}: rsync]: Copy from $SOURCE_HOST to $DEST_HOST completed

Copy from $SOURCE_HOST to $DEST_HOST completed
EOF
