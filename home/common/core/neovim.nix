{
  inputs,
  lib,
  pkgs,
  osConfig,
  config,
  ...
}:
let
  # From github, but useful for nested terminals. Tie to nvim terminal and add
  # https://github.com/sephid86/nixos/blob/5eefc2eb3c3f2afc362235682176f42916c8b948/homenix/home.nix#L362
  nvim-add = pkgs.writeShellApplication {
    name = "nvim-add";
    runtimeInputs = [ config.wrappers.neovim.wrapper ];
    text = ''
      #!/usr/bin/env bash
      NVIM_SOCKET="$HOME/.cache/nvim.sock"
      # [ "$#" -gt 0 ] && set -- $(realpath -- "$@")
      if [ "$#" -gt 0 ]; then
          mapfile -t real_files < <(realpath -- "$@")
          set -- "''${real_files[@]}"
      fi
      if n_=$(nvim --headless --server "$NVIM_SOCKET" --remote-expr "1" 2>/dev/null); then
      if [ "$#" -eq 0 ]; then set -- "unnamed"; fi
        exec nvim --server "$NVIM_SOCKET" --remote "$@"
      else
        rm -f $NVIM_SOCKET
        exec nvim --listen "$NVIM_SOCKET" "$@"
      fi
    '';
  };
in
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
        terminalMode = osConfig.hostSpec.useNeovimTerminal;
        guifont =
          let
            fontSize = 12; # FIXME: This should come from somewhere else
          in
          # FIXME: Doesn't seem to work when setting all fonts, so just defaulting to first for now
          [ (lib.head osConfig.fonts.fontconfig.defaultFonts.monospace) ]
          |> map (f: "${f}:h${toString fontSize}")
          |> lib.concatStringsSep ",";
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
  home.packages = [ nvim-add ];
}
