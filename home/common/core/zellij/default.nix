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
  # See https://github.com/dj95/zjstatus/discussions/44 for some ricing ideas
  # Use manual file until extraConfig PR is fixed
  xdg.configFile = {
    "zellij/config.kdl".source = ./config.kdl;
    #"zellij/layouts/default.kdl".source = ./default_layout.kdl;
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
