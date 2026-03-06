{
  inputs,
  lib,
  # pkgs,
  osConfig,
  ...
}:
{
  imports = [
    (inputs.wrappers.lib.mkInstallModule {
      loc = [
        "home"
        "packages"
      ];
      name = "neovim";
      value = inputs.fidgetingvim.wrapperModules.default;
    })
  ];

  wrappers.neovim =
    let
      isDev = osConfig.hostSpec.useWindowManager;
    in
    {
      enable = true;
      settings = {
        neovide = isDev;
        # NOTE: This means you need the neovim source at the specified unwrapped_config path
        # ex ~/dev/nix/neovim
        devMode = isDev;
        terminal = osConfig.hostSpec.useNeovimTerminal;
      };
    };

  programs.zsh = {
    shellAliases = {
      vi = "nvim";
      vim = "nvim";
    }
    // lib.optionalAttrs osConfig.hostSpec.useNeovimTerminal {
      # This is so we don't spawn embedded neovim if already in a neovim terminal
      # FIXME: Maybe look into vimception plugin to fix this eventually
      # neovim = "${pkgs.introdus.neovim-wrapped}/bin/neovim.sh";
    };
  };
}
