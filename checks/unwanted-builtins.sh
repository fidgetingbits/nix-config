#! /usr/bin/env bash
set -euo pipefail

# Flag anything that isn't builtins-only
# WARNING: This list is incomplete. Things will have to be added to it overtime
rg -g "*.nix" "builtins" | rg -v '(toString|toFile|readDir|currentTime|getFlake|getEnv|isNull)'
