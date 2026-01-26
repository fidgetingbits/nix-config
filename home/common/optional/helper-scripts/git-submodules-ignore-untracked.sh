#!/usr/bin/env bash
set -euo pipefail

if [[ $(git rev-parse --is-inside-work-tree 2>/dev/null) != 'true' ]]; then
    echo "ERROR: Not in a git repository"
    return 1
fi

if [[ ! -f .gitmodules ]]; then
    echo "ERROR: No .gitmodules file found"
    return 1
fi

module_list=$(git ls-files --stage | grep '^160000 ' | awk '{print $NF}')
echo "Identified $(echo "$module_list" | wc -l) submodules"
for module in $module_list; do
    echo "Setting ignore untracked for submodule $module"
    git config -f .gitmodules submodule."$module".ignore untracked
done
