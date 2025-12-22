#!/usr/bin/env bash

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../../introdus/pkgs/introdus-helpers/helpers.sh"

trap cleanup_flake_lock EXIT HUP INT QUIT TERM

if [[ $# -ne 1 ]]; then
	echo "Usage: $0 HOST"
	exit 1
fi

HOST="$1"

NIXPKGS_ALLOW_BROKEN=1 NIX_SSHOPTS="-p10022" nixos-rebuild \
	--target-host "$HOST" \
	--sudo \
	--show-trace \
	--impure \
	--flake .#"$HOST" \
	switch
