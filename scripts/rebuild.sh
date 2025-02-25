#!/usr/bin/env bash
# shellcheck disable=SC2086
#
# This script is used to rebuild the system configuration for the current host.
#
# SC2086 is ignored because we purposefully pass some values as a set of arguments, so we want the splitting to happen

# Helpers library
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

switch_args="--show-trace --impure --flake "
if [[ -n $1 && $1 == "trace" ]]; then
	switch_args="$switch_args --show-trace "
elif [[ -n $1 ]]; then
	HOST=$1
else
	HOST=$(hostname)
fi
switch_args="$switch_args .#$HOST switch"

os=$(uname -s)
if [ "$os" == "Darwin" ]; then
	# On Darwin we end up doing some bootstrapping just in case
	mkdir -p ~/.config/nix || true
	CONF=~/.config/nix/nix.conf
	if [ ! -f $CONF ]; then
		# Enable nix-command and flakes to bootstrap
		cat <<-EOF >$CONF
			experimental-features = nix-command flakes
		EOF
	fi

	# Do some darwin pre-installation for bootstrapping
	if ! which git &>/dev/null; then
		echo "Installing xcode tools"
		xcode-select --install
	fi

	# https://docs.brew.sh/Installation
	if [ ! -e /opt/homebrew/bin/brew ]; then
		echo "Installing rosetta"
		# This is required for emulation of x86_64 binaries, so let's just
		# assume if they didn't install brew yet, they need this
		softwareupdate --install-rosetta --agree-to-license
		echo "Installing homebrew"
		export NONINTERACTIVE=1
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
	fi

	green "====== REBUILD ======"
	# Test if there's no darwin-rebuild, then use nix build and then run it
	if ! which darwin-rebuild &>/dev/null; then
		nix build --show-trace .#darwinConfigurations."$HOST".system
		./result/sw/bin/darwin-rebuild $switch_args
	else
		echo $switch_args
		darwin-rebuild $switch_args
	fi
else
	green "====== REBUILD ======"
	if command -v nh &>/dev/null; then
		REPO_PATH=$(pwd)
		export REPO_PATH
		# Stop nix from trying to update the flake.lock file since it's untracked
		git add --intent-to-add -f flake.lock
		nh os switch . -- --impure --show-trace
		git rm --cached flake.lock
	else
		sudo nixos-rebuild $switch_args
	fi
fi

# shellcheck disable=SC2181
if [ $? -eq 0 ]; then
	green "====== POST-REBUILD ======"
	green "Rebuilt successfully"

	# Check if there are any pending changes that would affect the build succeeding.
	if git diff --exit-code >/dev/null && git diff --staged --exit-code >/dev/null; then
		# Check if the current commit has a buildable tag
		if git tag --points-at HEAD | grep -q buildable; then
			yellow "Current commit is already tagged as buildable"
		else
			git tag buildable-"$(date +%Y%m%d%H%M%S)" -m ''
			green "Tagged current commit as buildable"
		fi
	else
		yellow "WARN: There are pending changes that would affect the build succeeding. Commit them before tagging"
	fi
fi
