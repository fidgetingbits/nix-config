#!/usr/bin/env bash
# This script is used to build a remote host. It's it's own script because of the
# need for the cleanup trap to avoid the pre-commit bug with per-host flake locks.

# Need this to avoid some wacky pre-commit hook issues related to if rebuild fails and
# flake.lock stays staged, which ends up wiping out all changes due to stashing bug
cleanup() {
    if [ $? -ne 0 ]; then
        echo "ERROR: Rebuild failed, cleaning up lock files"
        git rm --cached -f flake.lock 2>/dev/null || true
        rm flake.lock 2>/dev/null || true
    fi
}
trap cleanup EXIT HUP INT QUIT TERM

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 HOST"
    exit 1
fi

HOST="$1"
NIX_SSHOPTS="-p10022" nixos-rebuild --target-host "$HOST" --use-remote-sudo --show-trace --impure --flake .#"$HOST" switch
