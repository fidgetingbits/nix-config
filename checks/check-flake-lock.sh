#! /usr/bin/env bash
set -euo pipefail

if [ -e flake.lock ]; then
    echo 'ERROR: flake.lock file detected'
    echo "Run the following before continuing:"
    echo "git rm -f flake.lock && rm -f flake.lock"
    exit 1
fi
