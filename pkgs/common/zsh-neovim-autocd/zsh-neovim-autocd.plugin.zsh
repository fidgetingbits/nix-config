# shellcheck disable=SC2148

neovim_autocd() {
	[[ $NVIM ]] && neovim-autocd
}

autoload -U add-zsh-hook
add-zsh-hook chpwd neovim_autocd
