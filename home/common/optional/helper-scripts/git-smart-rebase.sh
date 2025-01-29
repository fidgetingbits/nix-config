#!/usr/bin/env bash
set -euo pipefail

GIT_STASH_MESSAGE="git-smart-rebase.sh: $RANDOM"
git stash push -m "$GIT_STASH_MESSAGE"
git fetch && git rebase
git stash list | grep "${GIT_STASH_MESSAGE}" && git stash pop
