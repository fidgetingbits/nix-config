#!/usr/bin/env bash
set -euo pipefail
# Build a development version of the extension that includes all my changes from various PRs

ORIG_BRANCH=$(git rev-parse --abbrev-ref HEAD)
FOLDER=~/dev/talon/fidgetingbits-cursorless-build
if [ ! -d "$FOLDER" ]; then
    git clone https://github.com/fidgetingbits/cursorless "$FOLDER"
fi
cd $FOLDER

# In "lite" mode we just install the extension without rebuilding, we need force because sometimes it thinks
# the version we built is not ok
if [ $# -ne 0 ]; then
    code --install-extension packages/cursorless-vscode/bundle.vsix --force
    echo "Installed dev build. Be sure to disable cursorless extension if not already using dev build."
    exit 0
fi

# Deal with any development I was doing
GIT_STASH_MESSAGE="build-command-server-pr-bundle.sh: $RANDOM"
git stash push -m "$GIT_STASH_MESSAGE"

git switch main
git fetch && git rebase
git branch -D dev-build 2>/dev/null || true
git fetch upstream
git rebase upstream/main
git switch -c dev-build
git merge origin/bash-lang -m "Merge branch 'bash-lang' into dev"
git merge origin/nix-lang -m "Merge branch 'nix-lang' into dev"
nix shell "nixpkgs#nodejs-18_x.pkgs.pnpm" "nixpkgs#vsce" --command pnpm install
nix shell "nixpkgs#nodejs-18_x.pkgs.pnpm" "nixpkgs#vsce" --command pnpm -F cursorless-vscode install-local
echo "Installed dev build. Be sure to disable cursorless extension if not already using dev build."
git switch "$ORIG_BRANCH"

git stash list | (grep "${GIT_STASH_MESSAGE}" && git stash pop) || true
