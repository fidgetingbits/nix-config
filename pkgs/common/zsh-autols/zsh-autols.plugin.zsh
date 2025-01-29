# shellcheck disable=SC2148

function autols() {
	emulate -L zsh
	files=$(find . -maxdepth 1 -type f | wc -l)
	# Don't fully output if there's too many files
	if [[ $files -gt "20" ]]; then
		# --color=always is needed to get the colors to show up in the head output
		# shellcheck disable=SC2012
		ls -1 --color=always | head -20
		echo "[SNIPPED]"
	else
		ls -1
	fi
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd autols
