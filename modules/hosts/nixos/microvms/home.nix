# base home-manager module for microvms
{
  pkgs,
  lib,
  user,
  inputs,
  ...
}:
{
  imports = lib.flatten [
    (map lib.custom.relativeToRoot [
      "home/common/core/zellij"
    ])
  ];

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
        ;
    };
  };

  xdg.enable = true;

  programs = {
    home-manager.enable = true;
    zsh = {
      enable = true;
      shellAliases = {
        # FIXME: Make this reference the config value somehow
        "cds" = "cd ~/dev/ai/shared/$(hostname)/";
        # Restricted microvm with no LAN access, so should be okay
        "claude" = "claude --dangerously-skip-permissions";
      };
      initContent =
        # FIXME: This should move to nano or agent-template home base, not all microvm
        lib.mkAfter
          # bash
          ''
            export ANTHROPIC_API_KEY=$(cat /run/secrets/anthropic_api_key)
            # export OPENAI_API_KEY=$(cat /run/secrets/openai_key})
          '';
    };
  };

  home.file =
    [
      ".claude/CLAUDE.md"
      ".config/pi/SYSTEM_APPEND.md"
    ]
    |> map (path: {
      "${path}".source = (lib.toString inputs.nix-secrets) + "/prompts/nano/base.md";
    })
    |> lib.mergeAttrsList;
}
