{
  lib,
  pkgs,
  config,
  ...
}:

{
  home.packages = [
    pkgs.neovim # overridden with nixvim
  ];

  programs.zsh = {
    # This is so we don't spawn embedded neovim if already in a neovim terminal
    shellAliases = lib.optionalAttrs config.hostSpec.useNeovimTerminal {
      vim = "nvim";
      vi = "nvim";
      # FIXME: Anything with -<command> is broken because ultimately it goes through neovim-openfile, which won't
      # handle the cmdline arguments properly
      ex = "nvim -e";
      rview = "nvim -RZ";
      rvim = "nvim -Z";
      view = "nvim -R";
      vimdiff = "nvim -d";
      neovim = "${pkgs.neovim-wrapped}/bin/neovim.sh";
    };
  };
}
