# Functionality common for microvm's running agent software
{
  pkgs,
  lib,
  inputs,
  osConfig,
  ...
}:
{
  imports = lib.flatten [
    (map lib.custom.relativeToRoot [
    ])
  ];

  home = {
    packages = lib.attrValues {
      inherit (pkgs)
        claude-code
        claude-agent-acp
        codex
        codex-acp
        gemini-cli
        pi-coding-agent
        ;
    };
    file =
      [
        ".claude/CLAUDE.md"
        ".config/pi/SYSTEM_APPEND.md"
        ".codex/AGENTS.md"
      ]
      |> map (path: {
        "${path}".source =
          (lib.toString inputs.nix-secrets) + "/prompts/${osConfig.networking.hostName}/base.md";
      })
      |> lib.mergeAttrsList;
  };

  programs = {
    zsh = {
      shellAliases = {
        # Restricted microvm with no LAN access, so should be okay
        "claude" = "claude --dangerously-skip-permissions";
      };
      initContent =
        lib.mkAfter
          # bash
          ''
            export ANTHROPIC_API_KEY=$(cat /run/secrets/anthropic_api_key)
            # export OPENAI_API_KEY=$(cat /run/secrets/openai_key})
          '';
    };
  };
}
