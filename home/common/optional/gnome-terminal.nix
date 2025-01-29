{ pkgs, ... }:
{
  programs.gnome-terminal = {
    enable = true;
    # uuid randomly generated with uuidgen
    profile."912a4fe3-3caf-4637-8140-5cad996f5686" = {
      default = true;
      audibleBell = false;

      # These options are all neovim-terminal-specific
      customCommand = "${pkgs.neovim}/bin/nvim -c ':term'";
      # FIXME: This spams the command-line with crap: zsh:~1337;SetUserVar=WEZTERM_PROG=1337;SetUserVar=WEZTERM_USER=YWE=1337;Se
      # even though I'm not using WEZTERM?
      # is related to this:
      # https://github.com/tmux/tmux/wiki/FAQ#what-is-the-passthrough-escape-sequence-and-how-do-i-use-it
      # Disabling wezterm fixes it.
      # Still have a separate program which is that `TERM: tmux` never gets replaced, like if you run gdb
      #customCommand = "${pkgs.tmux}/bin/tmux new -- ${pkgs.neovim}/bin/nvim -c ':term'";

      visibleName = "neovim terminal";
      showScrollbar = false;

    };
    showMenubar = false;
    themeVariant = "dark";
  };
}
