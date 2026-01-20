#!/usr/bin/env bash
#
# Adapted from: https://blog.tnez.dev/posts/supercharge-workflow-with-git-worktrees/
#
# Simplified worktree creation with automatic tracking

function help_and_exit() {
    echo "USAGE: $(basename "$0") <branch>"
    exit 0
}

parse_args() {
    local min_args=$1
    shift

    if [ $# -lt "$min_args" ]; then
        help_and_exit
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --debug)
            if [ $# -lt $((min_args + 1)) ]; then
                help_and_exit
            fi
            set -x
            ;;
        -h | --help)
            help_and_exit
            ;;
        *)
            if [ -z "${POSITIONAL_ARGS-}" ]; then
                POSITIONAL_ARGS=()
            fi
            POSITIONAL_ARGS+=("$1")
            ;;
        esac
        shift
    done
}

parse_args "1" "$@"
BRANCH_NAME="${POSITIONAL_ARGS[0]}"

# NOTE: Caveat here is that this doesn't allow nested worktrees
GIT_ROOT=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)

if [ -z "$GIT_ROOT" ]; then
    echo "Error: You must run this from within a Git repository."
    exit 1
fi

# Go to the parent of the git directory so worktrees are created side-by-side
cd "$GIT_ROOT/.." || (echo "Failed to cd to $GIT_ROOT/.." && exit)

# Ensure we have proper remote tracking (needed for bare repos)
git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

# Fetch latest refs to ensure we have all remote branches
git fetch origin

# 1. Check if the branch exists locally
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    # Check for unpushed commits
    UPSTREAM=$(git rev-parse --abbrev-ref "$BRANCH_NAME@{u}" 2>/dev/null || true)
    if [ -n "$UPSTREAM" ]; then
        UNPUSHED=$(git log "$UPSTREAM..$BRANCH_NAME" --oneline)
        if [ -n "$UNPUSHED" ]; then
            echo "Warning: Local branch '$BRANCH_NAME' has unpushed commits."
            echo "Checking out existing local state to avoid data loss."
            git worktree add "$BRANCH_NAME" "$BRANCH_NAME"
            exit 0
        fi
    fi

    echo "Syncing local branch with origin/$BRANCH_NAME..."
    git worktree add -B "$BRANCH_NAME" "$BRANCH_NAME" "origin/$BRANCH_NAME"

# 2. If it only exists on remote
elif git ls-remote --exit-code --heads origin "$BRANCH_NAME" >/dev/null 2>&1; then
    echo "Creating worktree for remote branch: $BRANCH_NAME"
    git worktree add --track -b "$BRANCH_NAME" "$BRANCH_NAME" "origin/$BRANCH_NAME"
# 3. Brand new branch
else
    echo "Creating worktree for new local branch: $BRANCH_NAME"
    # Use the first existing worktree's branch as base, or fallback to origin/main
    BASE_BRANCH=$(git worktree list --porcelain | grep "branch refs/heads/" | head -1 | sed 's/branch refs\/heads\///')
    if [ -z "$BASE_BRANCH" ]; then
        BASE_BRANCH="origin/main"
    fi
    git worktree add -b "$BRANCH_NAME" "$BRANCH_NAME" "$BASE_BRANCH"
    echo "Remember to 'git push -u origin $BRANCH_NAME' when ready to push"
fi
