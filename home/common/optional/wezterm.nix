{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.wezterm = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    extraConfig = # lua
      ''
        return {
      ''
      + lib.optionalString config.hostSpec.useNeovimTerminal ''
        default_prog = { "${pkgs.neovim-term}/bin/neovim-term.sh" },
      ''
      + ''
            hide_tab_bar_if_only_one_tab = true,
            window_padding = {
              left = 0,
              right = 0,
              top = 0,
              bottom = 0,
            },
        }
      '';
  };
}
