#!/usr/bin/env bash
# This let's me quickly validate what plugins are installed by nixvim

exec_line=$(grep exec <"$(type -p nvim | cut -f 3 -d ' ')")
packdir=$(echo "${exec_line}" | grep -oP '(?<=set packpath\^=)[^"]*')
fullpath="${packdir}"/pack/myNeovimPackages/start
echo "Plugins installed in: $fullpath"
ls "$fullpath"
