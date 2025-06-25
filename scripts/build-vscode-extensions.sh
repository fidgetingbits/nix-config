#!/usr/bin/env bash
set -eo pipefail

# This script is used to build the voice coding extensions for the current host,
# only if fits actually a voice coding system.
#
# An optional argument is used which may cause the extension building to use the light version

# Build the extensions only on hosts that have 'voiceCoding.enable = true' in
# their config.

root_path=$(git rev-parse --show-toplevel)
if grep 'voiceCoding.enable = true' "$root_path/hosts/nixos/$(hostname)/default.nix"; then
	build-cursorless-pr-bundle "$1" || true
	build-command-server-pr-bundle "$1" || true
fi
