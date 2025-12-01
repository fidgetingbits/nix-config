#!/usr/bin/env bash
# This script is used to build a remote host. It's it's own script because of the
# need for the cleanup trap to avoid the pre-commit bug with per-host flake locks.

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

trap cleanup_flake_lock EXIT HUP INT QUIT TERM

if [[ $# -ne 1 ]]; then
	echo "Usage: $0 HOST"
	exit 1
fi

HOST="$1"
NIX_SSHOPTS="-p10022" nixos-rebuild --target-host "$HOST" --sudo --show-trace --impure --flake .#"$HOST" switch
