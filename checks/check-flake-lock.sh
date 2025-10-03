#! /usr/bin/env bash
set -euo pipefail

if [ -e flake.lock ]; then
    echo 'Error: flake.lock file detected'
    echo "Delete it before continuing"
    exit 1
fi
