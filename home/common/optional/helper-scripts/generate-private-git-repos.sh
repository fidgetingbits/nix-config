#!/usr/bin/env bash
set -euo pipefail

echo '"github.com" = ['
gh repo list --visibility=private --limit 1000 | while read -r repo; do
	path=$(echo "$repo" | awk '{print $1}')
	echo "    \"$path\""
done
gh api user/orgs --paginate | jq -r '.[].login' | while read -r org; do
	gh repo list "$org" --visibility=private --limit 1000 | while read -r repo; do
		path=$(echo "$repo" | awk '{print $1}')
		echo "    \"$path\""
	done
done
echo "];"

echo '"gitlab.com" = ['
glab api 'projects?membership=true&visibility=private' --paginate 2>/dev/null | jq '.[].path_with_namespace' | while read -r path; do
	echo "    $path"
done

echo "];"
