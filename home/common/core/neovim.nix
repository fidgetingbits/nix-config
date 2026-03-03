{
  inputs,
  lib,
  pkgs,
  osConfig,
  ...
}:
{
  imports = [
    # inputs.fidgetingvim.wrapperModules.fidgetingvim
  ];

  home.packages = [
    #pkgs.fidgetingvim
    # inputs.fidgetingvim.outputs.fidgetingvim
    inputs.fidgetingvim.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # wrappers.fidgetingvim = {
  #   enable = true;
  #   dev_mode = true;
  # };

  programs.zsh = {
    shellAliases = {
      vi = "nvim";
      vim = "nvim";
    }
    // lib.optionalAttrs osConfig.hostSpec.useNeovimTerminal {
      # This is so we don't spawn embedded neovim if already in a neovim terminal
      # FIXME: Maybe look into vimception plugin to fix this eventually
      # neovim = "${pkgs.introdus.neovim-wrapped}/bin/neovim.sh";
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
