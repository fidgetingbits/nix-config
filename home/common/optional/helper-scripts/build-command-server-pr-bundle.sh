#!/usr/bin/env bash
set -euo pipefail

# Build a development version of the extension that includes all my changes from various PRs

ORIG_BRANCH=$(git rev-parse --abbrev-ref HEAD)
FOLDER=~/dev/talon/fidgetingbits-command-server
if [ ! -d "$FOLDER" ]; then
	echo "WARNING: Cursorless development folders not initialized. Bootstrap them to continue."
	exit 1
fi
cd $FOLDER

# In "lite" mode we just install the extension without rebuilding
if [ $# -ne 0 ]; then
	code --force --install-extension result/*.vsix
	echo "Installed command-server dev build."
	exit 0
fi

# Deal with any development I was doing
GIT_STASH_MESSAGE="build-command-server-pr-bundle.sh: $RANDOM"
git stash push -m "$GIT_STASH_MESSAGE"

git switch main
git fetch && git rebase
git branch -D dev-build 2>/dev/null || true
#git fetch upstream
#git rebase upstream/main
git switch -c dev-build
git merge origin/use-static-tmp-dir -m "Merge branch 'use-static-tmp-dir' into dev"
git merge origin/nix-flake -m "Merge branch 'nix-flake' into dev"
nix build
code --force --install-extension result/*.vsix
echo "Installed command-server dev build."
git switch "$ORIG_BRANCH"

git stash list | grep "${GIT_STASH_MESSAGE}" && git stash pop
