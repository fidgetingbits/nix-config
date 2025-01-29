#! /usr/bin/env bash
set -euo pipefail

if [ -d .git-crypt ]; then
	STAGED_FILES=$(git diff --cached --name-status | awk '$1 != "D" { print $2 }' | xargs echo)
	if [ -n "${STAGED_FILES}" ]; then
		# shellcheck disable=SC2086
		if ! git-crypt status ${STAGED_FILES} &>/dev/null; then
			git-crypt status -e ${STAGED_FILES}
			echo 'Error: Unencrypted files found that should be encrypted'
			echo 'Please:'
			echo "1. git restore --staged ${STAGED_FILES}"
			echo "2. git-crypt unlock (if not already unlocked)"
			echo "3. git add ${STAGED_FILES}"
			exit 1
		fi
	fi
fi
