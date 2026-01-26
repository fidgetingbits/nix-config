#!/usr/bin/env bash
set -euo pipefail

function talon_folders() {
    find -L "$HOME/.talon/user/" -mindepth 1 -maxdepth 1 -type d -print0 | while IFS= read -r -d '' repo; do
        if [ -L "$repo" ]; then
            repo=$(readlink -f "$repo")
        fi
        echo "$repo"
    done
}

# Not all of these will exist on every system, but we deal with that later
repo_paths=(
    "$HOME/dev/nix/nix-config"
    "$HOME/dev/nix/nixvim-flake"
    "$HOME/dev/nix/nix-secrets"
)

while IFS= read -r line; do
    repo_paths+=("$line")
done < <(talon_folders)

for i in "${repo_paths[@]}"; do
    if [ ! -d "$i" ]; then
        echo "Skipping $i, not a directory"
        continue
    fi
    cd "$i"
    echo "Updating $i"
    GIT_STASH_MESSAGE="update-core-repos.sh: $RANDOM"
    git stash push -m "$GIT_STASH_MESSAGE"
    git fetch && git rebase
    git stash list | grep "${GIT_STASH_MESSAGE}" && git stash pop
    cd - >/dev/null
done
