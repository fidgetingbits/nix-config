# base home-manager module for microvms
{
  pkgs,
  lib,
  user,
  ...
}:
{
  config = {
    home = {
      username = user;
      homeDirectory = "/home/${user}";
      stateVersion = "26.05";

      packages = lib.attrValues {
        inherit (pkgs)
          delta
          difftastic
          direnv
          fd
          git
          htop
          just
          jq
          ripgrep
          tree
          curl
          python3
          openssh
          neovim # FIXME: (overlay our neovim package, etc?)
          strace
          zellij
          ;
      };
    };

    xdg.enable = true;

    programs = {
      home-manager.enable = true;
      zsh = {
        enable = true;
        initContent =
          # FIXME: This should move to ai-agent home base
          lib.mkAfter
            # bash
            ''
              export ANTHROPIC_API_KEY=$(cat /run/secrets/anthropic_api_key)
            '';
      };
    };
  };
}
