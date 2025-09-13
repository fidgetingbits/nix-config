{
  lib,
  pkgs,
  ...
}:
{
  programs.zellij = {
    enable = true;
    package = pkgs.unstable.zellij;
    #    enableZshIntegration = false; # NOTE: true forces zellij upon opening zsh
    #    settings = {
    #      default_mode = "locked";
    #      ui.pane_frames = {
    #        rounded_corners = true;
    #        hide_session_name = true;
    #      };
    #      #keybinds = import ./keybinds.nix;
    #    };
    #    extraConfig = ''
    #      // Test
    #    '';
  };
  home.file.".config/zellij/config.kdl".source = ./config.kdl;

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
