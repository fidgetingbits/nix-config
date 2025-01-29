# shellcheck disable=SC2148

# This function will continued to cd into deeper and deeper into the directory
# until it finds more than one file. Idea came from here:
# https://karl-voit.at/2017/07/23/zsh-skip-empty-dirs/
# FIXME - How do we avoid this if we explicitly want to enter a directory that
# doesn't have it any other files?
function deep_autocd() {
	files=$(find . -maxdepth 1 -type f | wc -l)
	if [[ $files == "1" ]]; then
		zmodload zsh/parameter
		# FIXME - this might need to be fuzzier?
		# shellcheck disable=SC2154,SC1087,SC2193
		if [[ "cd .." != "$history[$HISTCMD]" ]]; then
			f=$(ls -A)
			if [[ -d $f ]]; then
				cd "$f" || exit
			fi
		fi
	fi
}
alias dcd=deep_autocd
