{
  lib,
  pkgs,
  config,
  ...
}:

{
  home.packages = [
    pkgs.nixcats
  ];

  programs.zsh = {
    shellAliases = {
      # These are set by nixCats flake now
      # nvim = "nixCats";
      # vim = "nixCats";
      # vi = "vim";
    }
    // lib.optionalAttrs config.hostSpec.useNeovimTerminal {
      # This is so we don't spawn embedded neovim if already in a neovim terminal
      # FIXME: Maybe look into vimception plugin to fix this eventually
      neovim = "${pkgs.neovim-wrapped}/bin/neovim.sh";
      # FIXME: Anything with -<command> is broken because ultimately it goes through neovim-openfile, which won't
      # handle the cmdline arguments properly
      ex = "nvim -e";
      rview = "nvim -RZ";
      rvim = "nvim -Z";
      view = "nvim -R";
      vimdiff = "nvim -d";
    };
  };
}
