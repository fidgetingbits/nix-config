#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
	cat <<HELP

dockertags  --  list all tags for a Docker image on a remote registry.

EXAMPLE:
    - list all tags for redis:
       dockertags redis

    - list all redis tags containing a 7.x release on alpine:
       dockertags redis '^7.*-alpine'

HELP
fi

image="$1"
filter=""
if [ $# -gt 1 ]; then
	filter="$2"
fi

image="$1"
tag_count=$(wget -q -O - https://hub.docker.com/v2/namespaces/library/repositories/"${image}"/tags | jq -r '.count')

# echo "Found ${tag_count} tags for ${image}."
tags=$(wget -q -O - https://hub.docker.com/v2/namespaces/library/repositories/"${image}"/tags?page_size=100 | jq -r '.results[].name')

tag_array=("${tags}")
if [ "${tag_count}" -gt 100 ]; then
	for i in $(seq 2 $(("${tag_count}" / 100))); do
		tags=$(wget -q -O - https://hub.docker.com/v2/namespaces/library/repositories/"${image}"/tags?page_size=100\&page="$i" | jq -r '.results[].name')
		tag_array+=("${tags}")
	done
fi

tags=$(printf "%s\n" "${tag_array[@]}" | sort -u)
if [ -n "$filter" ]; then
	tags=$(echo "${tags}" | grep -e "$filter")
fi
echo "$(echo "${tags}" | wc -l)" "tags found."
echo "${tags}"
