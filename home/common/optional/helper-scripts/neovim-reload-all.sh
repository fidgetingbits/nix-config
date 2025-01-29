#!/usr/bin/env bash
set -euo pipefail

# nixvim doesn't expose it's generated init.lua anywhere, but it does give nixvim-print-lua, which we can use...
# This script will identify every running neovim instance, and use pynvim to attach to it via RPC and reload the latest
# lua file from nixvim. This is useful for development, because all of the terminals on my system are neovim, and if I
# update something important and rebuild my nix config, I have no way to update the running instances without closing
# them all.

TMPFILE=$(mktemp)
nixvim-print-init >"$TMPFILE"
for PID in $(pgrep nvim); do
	# Get the socket path for the neovim instance
	SOCKET_PATH=/run/user/$UID/nvim.${PID}.0
	if [ -z "$SOCKET_PATH" ]; then
		echo "No socket path found for PID $PID"
		continue
	fi

	command nvim --headless --server "$SOCKET_PATH" --remote-send "<C-\><C-N>:luafile $TMPFILE<CR>:echo 'Reloaded nixvim config'<CR>" || true
	echo "Reloaded neovim instance with PID $PID"
done

# We also want to update the plugins by modifying the runtimepath maybe? Otherwise it won't actually reload new versions
# of the plugins
