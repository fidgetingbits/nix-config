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
  # Use manual file until extraConfig PR is fixed
  home.file.".config/zellij/config.kdl".source = ./config.kdl;

  programs.zsh = {
    shellAliases = {
      zl = "zellij";
      zls = "zellij list-sessions";
      zla = "zellij attach";
    };
    initContent = lib.readFile ./zellij_session_completions;
  };
}
