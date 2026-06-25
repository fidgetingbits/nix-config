# Functionality common for microvm's running agent software
{
  pkgs,
  lib,
  inputs,
  osConfig,
  vmSpecs,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };
  # FIXME: de-duplicate this file with home/common/optional/agents.nix
  models.providers = {
    ossa = {
      # FIXME: Need to pass ports from network into the vms, into vmSpecs I guess
      baseUrl = "http://${vmSpecs.vm-lan.hosts.gateway.ip}:11435/v1";
      api = "openai-completions";
      apiKey = "foo";
      models = [
        {
          id = "qwen3-vl:8b";
          name = "Qwen 3 VL (8B Thinking GGUF)";
        }
      ];
    };
  };
in
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
        crush
        gemini-cli
        pi-coding-agent
        ;
    };
    file =
      let
        genPrompts =
          [
            ".claude/CLAUDE.md"
            ".pi/SYSTEM_APPEND.md"
            ".codex/AGENTS.md"
          ]
          |> map (path: {
            "${path}".source =
              (lib.toString inputs.nix-secrets) + "/prompts/${osConfig.networking.hostName}/base.md";
          })
          |> lib.mergeAttrsList;
      in
      {
        ".pi/agent/models.json".source = jsonFormat.generate "pi-coding-agent-models.json" models;
      }
      // genPrompts;
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
            export OPENAI_API_KEY=$(cat /run/secrets/openai_api_key)
            export DEEPSEEK_API_KEY=$(cat /run/secrets/deepseek_api_key)
            export GEMINI_API_KEY=$(cat /run/secrets/google_api_key)
          '';
    };
  };
}
