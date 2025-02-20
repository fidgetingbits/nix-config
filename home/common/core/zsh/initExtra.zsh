# shellcheck disable=SC2148
## yubikey-agent
# export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/yubikey-agent/yubikey-agent.sock"

# Override some GUI entries if inside ssh session
if [[ -n $SSH_CONNECTION ]]; then
	export GIT_EDITOR="nvim"
	export EDITOR="nvim"
	export VISUAL="nvim"
fi

unsetopt correct # autocorrect commands

setopt hist_ignore_all_dups # remove older duplicate entries from history
setopt hist_reduce_blanks   # remove superfluous blanks from history items
setopt inc_append_history   # save history entries as soon as they are entered
setopt share_history        # share history between different instances of the shell

# auto complete options
setopt auto_list                                                            # automatically list choices on ambiguous completion
setopt auto_menu                                                            # automatically use menu completion
setopt always_to_end                                                        # move cursor to end if word had one match
zstyle ':completion:*' menu select                                          # select completions with arrow keys
zstyle ':completion:*' group-name ""                                        # group results by category
zstyle ':completion:::::' completer _expand _complete _ignored _approximate # enable approximate matches for completion

# Keep history of `cd` as in with `pushd` and make `cd -<TAB>` work.
# shellcheck disable=SC2034
DIRSTACKSIZE=16
setopt auto_pushd
setopt pushd_ignore_dups
setopt pushd_minus

##
# zle key remapping
##
# ^[3~ is sent by many terminals for the delete key
bindkey '^[[3~' delete-char
# ^[3;5~ is sent by some terminals for ctrl+delete key
bindkey '^[3;5~' delete-char
bindkey '^[[K' backward-kill-line
bindkey '^[[U' undo # ^_ seems to be zoom related in wezterm
bindkey '^[[Z' redo
bindkey '^[[b' vi-backward-blank-word
bindkey '^[[f' vi-forward-blank-word
bindkey -r '^@' # This fucks up on my system, but I still need set-mark-command
bindkey '^[[m' set-mark-command
bindkey '^[%' vi-match-bracket
bindkey '^X^P' vi-find-prev-char
bindkey '^[^K' kill-whole-line

# FIXME(zsh): Figure out how todo the indenting for junk for zle
# function indent-line {
#     zle set-mark-command
#     zle beginning-of-line
#     zle redisplay
#     zle -U $'\t'
#     zle exchange-point-and-mark
# }

# function unindent-line {
#     zle -M set-mark-command
#     zle -M beginning-of-line
#     zle redisplay

#     # If the line starts with a tab or a space, delete it
#     if [[ $LBUFFER == $'\t'* ]]; then
#         zle -U $'\C-h'
#     elif [[ $LBUFFER == ' '* ]]; then
#         zle -U $'\C-h'
#     fi
#     CURSOR=$MARK
#     # zle redisplay
# }

# zle -N indent-line
# zle -N unindent-line

bindkey '^[>' indent-line
bindkey '^[<' unindent-line

# This is for debugging only...
function zle-show-mark {
	zle -M "Cursor at $CURSOR, Mark at $MARK"
}
zle -N zle-show-mark
bindkey '^[[[m' zle-show-mark

##
# Navigation
##

# https://github.com/junegunn/fzf/wiki/examples#changing-directory
# shellcheck disable=SC2034
FZF_CMD="fzf --preview 'ls | head -n 10' --height=10 --reverse +m"
# fuzzy directory deep
# --preview 'awk -v n={1} -v l=1 "{print l==n ? 0 \" \" \$0 : l \" \" \$0; l++}"'
#         -o -type d -print 2>/dev/null | fzf --preview 'ls -l {} | head -n 10' --height=10 --reverse +m) &&

function fdd() {
	local dir
	dir=$(find "${1:-.}" -path '*/\.*' -prune \
		-o -type d -print 2>/dev/null | fzf --preview 'ls -l {} | head -n 10' --height=10 --reverse +m) &&
		cd "$dir" || exit
}

# fuzzy directory shallow
function fds() {
	local dir
	dir=$(find ./* -maxdepth 0 -type d -print 2>/dev/null | fzf +m) &&
		cd "$dir" || exit
}

# fdr - cd to selected parent directory
function fdr() {
	local dirs=()
	get_parent_dirs() {
		if [[ -d ${1} ]]; then dirs+=("$1"); else return; fi
		if [[ ${1} == '/' ]]; then
			for _dir in "${dirs[@]}"; do echo "$_dir"; done
		else
			get_parent_dirs "$(dirname "$1")"
		fi
	}

	local DIR=""
	DIR=$(get_parent_dirs "$(realpath "${1:-$PWD}")" | fzf-tmux --tac)
	cd "$DIR" || exit
}

##
# Misc functions
##
nameshell() {
	echo -ne "\033]0;$*\007"
}

reload() {
	exec "${SHELL}" "$@"
}

escape() {
	# useful when you need to translate weird paths into single-argument string.
	local escape_string_input
	echo -n "String to escape: "
	# shellcheck disable=SC2162
	read escape_string_input
	printf '%q\n' "$escape_string_input"
}

# Talon plugins
#source ~/.talon/user/fidget/apps/zsh/zsh-completion-server/setup.zsh

# FIXME: Using $XDG_RUNTIME_DIR due to https://github.com/Mic92/sops-nix/issues/287

# Need to add a work-only option for this

#if [ "$(uname -s)" = "Darwin" ]; then
#    source $(getconf DARWIN_USER_TEMP_DIR)/secrets/ida_teams_vault
#else
#    source $XDG_RUNTIME_DIR/secrets/ida_teams_vault
#fi

# Fix a bug where nixvim sets BAT_THEME to whatever colorscheme is used, which doesn't often exist
# shellcheck disable=SC2034
# There's a bug in stylix where it adds lower case
BAT_THEME="Dracula"

# We shouldn't need this with programs.zoxide.enableZshIntegration but I seem to anyway :/
eval "$(zoxide init zsh)"

nix_wrapper() {
	if [[ $1 == "build" ]]; then
		shift
		nix_log_extract build "$@"
	else
		command nix "$@"
	fi
}

nix_log_extract() {
	# Run the original nix command and capture its output
	temp_file=$(mktemp)
	script -q -f "$temp_file" -c "command nix $*"
	drv_line=$(grep "For full logs, run" "$temp_file")

	if [ -n "$drv_line" ]; then
		# NOTE: The hard coding use of .drv is to prevent color sequences being tacked on the end
		# shellcheck disable=SC2001
		NIX_LAST_DERIVATION=$(echo "$drv_line" | sed "s/.*nix log \(.*\.drv\).*/\1/")
		export NIX_LAST_DERIVATION
		echo "Run nix-log-last to view log from $NIX_LAST_DERIVATION"
	fi
	rm "$temp_file"
}

# Helper to disable tab completion in some slow folders
# See https://superuser.com/questions/585545/how-to-disable-zsh-tab-completion-for-nfs-dirs
# Shellcheck doesn't like a lot of the zsh-specific stuff in here, so just disable for now
# shellcheck disable=all
# FIXME: Re-enable this once I figure out how to disable shfmt breaking checks
# function restricted-expand-or-complete() {
#
#    # split into shell words also at "=", if IFS is unset use the default (blank, \t, \n, \0)
#    local IFS="${IFS:- \n\t\0}="
#
#    # this word is completed
#    local complt
#
#    # if the cursor is following a blank, you are completing in CWD
#    # the condition would be much nicer, if it's based on IFS
#    # fmt: off
#    if [[ $LBUFFER[-1] = " " || $LBUFFER[-1] = "=" ]]; then
#       complt="$PWD"
#    else
#       # otherwise take the last word of LBUFFER
#       complt=${${=LBUFFER}[-1]}
#    fi
#
#    # determine the physical path, if $complt is not an option (i.e. beginning with "-")
#    [[ ${complt[1]} = "-" ]] || complt=${complt:A}/
#    # fmt: on
#
#    # activate completion only if the file is on a local filesystem, otherwise produce a beep
#    if [[ ! $complt = /mnt/* && ! $complt = /another/nfs-mount/* ]]; then
#       zle expand-or-complete
#    else
#       echo -en "\007"
#    fi
# }
# zle -N restricted-expand-or-complete
# bindkey "^I" restricted-expand-or-complete

alias nix='nix_wrapper'
alias nix-log-last='NIX_PAGER=cat nix log $NIX_LAST_DERIVATION'
