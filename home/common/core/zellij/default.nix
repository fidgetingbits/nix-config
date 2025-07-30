{
  lib,
  pkgs,
  ...
}:
{
  home.packages = [
    # For some reason enabling it doesn't actually install it (at least in my PATH)
    pkgs.unstable.zellij
  ];
  #  programs.zellij = {
  #    enable = true;
  #    #package = pkgs.unstable.zellij;
  #    enableZshIntegration = false; # NOTE: true forces zellij upon opening zsh
  #    settings = {
  #      show_startup_tips = false;
  #      pane_frames = false;
  #      #default_layout = "compact"; # NOTE: compact removes the keybindings hint
  #    };
  #  };

  programs.zsh = {
    shellAliases = {
      zl = "zellij";
      zls = "zellij list-sessions";
      zla = "zellij attach";
    };
    initContent = lib.readFile ./zellij_session_completions;
  };
}
