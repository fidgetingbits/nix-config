# See https://github.com/dj95/zjstatus/discussions/44 for some ricing ideas
# Interesting way to auto-update plugins:
# https://github.com/viperML/dotfiles/blob/master/modules/wrapper-manager/zellij/default.nix
{
  lib,
  pkgs,
  ...
}:
{
  programs.zellij = {
    enable = true;
    package = pkgs.unstable.zellij;
  };
  xdg.configFile = {
    # Use manual file until extraConfig PR is fixed
    "zellij/config.kdl".source = ./config.kdl;
    "zellij/layouts/".source = ./layouts;
  };

  programs.zsh = {
    shellAliases = {
      zl = "zellij";
      zls = "zellij list-sessions";
      zla = "zellij attach";
      zld = "zellij action dump-layout"; # Save current layout
    };
    initContent = lib.readFile ./zellij_session_completions;
  };
}
