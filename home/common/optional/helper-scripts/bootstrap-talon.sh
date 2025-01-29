#!/usr/bin/env bash

# The community repo you want to use
# COMMUNITY_LINK=https://github.com/talonhub/community
COMMUNITY_LINK=https://github.com/fidgetingbits/fidgetingbits-talon
# Private repo (optional)
PRIVATE_LINK=ssh+git://oath_gitlab/aa/talon_private
# Private repo name override (optional)
PRIVATE_NAME=private
# Extra plugin repos (optional)
# FIXME: I use https://github.com/fidgetingbits/cursorless for cursorless now.., so need to special case
# FIXME: talon-vim is using the dev branch atm... so this will break
EXTRAS_LINKS=(
	"https://github.com/cursorless-dev/cursorless"
	"https://github.com/wolfmanstout/talon-gaze-ocr"
	"https://github.com/david-tejada/rango-talon"
	"https://github.com/fidgetingbits/talon-vim"
	"https://github.com/C-Loftus/talon-ai-tools"
	"https://github.com/fidgetingbits/talon-shotbox"
)
# Extra plugin repos for mac (optional)
EXTRAS_MAC_LINKS=(
	"https://github.com/phillco/talon-axkit"
)

REQUIRED_UTILS=(git wget)
UTILS_MISSING=0
for util in "${REQUIRED_UTILS[@]}"; do
	if ! command -v "${util}" >/dev/null; then
		echo "[-] ${util} not found"
		UTILS_MISSING=1
	fi
done
if [[ ${UTILS_MISSING} -eq 1 ]]; then
	echo "[-] Please install missing utils"
	exit 1
fi

# Where to clone all of the talon repos. Links will be created in TALON_USER
if [[ -z $TALON_SOURCE ]]; then
	TALON_SOURCE=~/source/talon
fi
echo "[+] Setting TALON_SOURCE to ${TALON_SOURCE}"

# Override on commandline if testing an install.
if [[ -z ${TALON_USER} ]]; then
	TALON_USER=~/.talon/user/
fi
echo "[+] Setting TALON_USER to ${TALON_USER}"

# Mac only
if [[ $OSTYPE == "darwin"* ]]; then
	EXTRAS_LINKS=("${EXTRAS_LINKS[@]}" "${EXTRAS_MAC_LINKS[@]}")
fi

OLDPWD=$(pwd)

LINKS=("${COMMUNITY_LINK}" "${PRIVATE_LINK}" "${EXTRAS_LINKS[@]}")
cd || exit

echo "[+] Creating ${TALON_USER}"
mkdir -p "${TALON_USER}" || true
echo "[+] Creating ${TALON_SOURCE}"
mkdir -p "${TALON_SOURCE}" || true
cd "${TALON_SOURCE}" || exit
echo "[+] Setting up repos"
for link in "${LINKS[@]}"; do
	REPO_NAME=$(basename "${link}")
	if [[ ${REPO_NAME} == *"private"* ]]; then
		# Because I make assumptions about the name of my private repo
		name=${PRIVATE_NAME}
	else
		name=$(basename "${link}")
	fi
	if [ ! -d "${name}" ]; then
		echo "[+] Cloning ${link} to ${name}"
		git clone "${link}" "${name}" >/dev/null
	else
		echo "[+] Skipping ${name} as it already exists"
	fi

	# Cursorless is a bit different, as we want to link to two places inside
	if [[ ${REPO_NAME} == *"cursorless"* ]]; then
		ln -sf "${TALON_SOURCE}/cursorless/${name}-talon" "${TALON_USER}"
		ln -sf "${TALON_SOURCE}/cursorless/${name}-talon-dev" "${TALON_USER}"
	elif [[ ${REPO_NAME} == *"talon_private"* ]]; then
		ln -sf "${TALON_SOURCE}/private/settings/parrot" ~/.talon/
	else
		ln -sf "${TALON_SOURCE}/${name}" "${TALON_USER}"
	fi
done

function yes_or_no {
	while true; do
		read -r -p "$* [y/n]: " yn
		case $yn in
		[Yy]*) return 0 ;;
		[Nn]*)
			# echo "Aborted"
			return 1
			;;
		esac
	done
}

if [[ -n ${PRIVATE_LINK} ]] && yes_or_no "[+] Symlink settings to private? N if unsure"; then
	echo "[+] Symlinking settings to private"
	if [[ -z ${PRIVATE_NAME} ]]; then
		PRIVATE_NAME=$(basename ${PRIVATE_LINK})
	fi

	COMMUNITY=$(basename ${COMMUNITY_LINK})
	rm -rf "${COMMUNITY}"/settings
	ln -sf ../"${PRIVATE_NAME}"/settings "${COMMUNITY}"/settings
else
	echo "[-] Skipping symlinks"
fi

# Need to run talon to setup this .talon/user/ directory structure?
# echo "[+] Enabling debug in engines.py"
# sed -i 's/debug=False/debug=True/' user/engines.py
# mv user ${HOME}/.talon/
# cd -

echo "[+] IMPORTANT: You still have to install a voice model manually from the talon taskbar icon"
cd "${OLDPWD}" || exit
