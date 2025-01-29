#!/usr/bin/env bash
set -eo pipefail

# This script is used to build the voice coding extensions for the current host,
# only if fits actually a voice coding system.
#
# An optional argument is used which may cause the extension building to use the light version

VOICE_CODING_HOSTS=("onyx" "orby" "oedo")
hostname=$(hostname)

for host in "${VOICE_CODING_HOSTS[@]}"; do
	if [ "$host" = "$hostname" ]; then
		echo "Building voice coding extensions for host: $host"
		build-cursorless-pr-bundle "$1" || true
		build-command-server-pr-bundle "$1" || true
	fi
done
