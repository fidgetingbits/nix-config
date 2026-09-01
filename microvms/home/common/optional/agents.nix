# Functionality common for microvm's running agent software
{
  pkgs,
  lib,
  inputs,
  osConfig,
  vmSpecs,
  namespace,
  ...
}:
{
  imports = lib.flatten [
    (map lib.custom.relativeToRoot [
      "home/common/optional/llm/agents.nix"
      "modules/home/pi-model-config.nix"
    ])
  ];

  home = {
    packages = lib.attrValues {
      # inherit (pkgs) ;
    };
    file =
      let
        perHostPromptFile =
          (lib.toString inputs.nix-secrets) + "/llm/prompts/${osConfig.networking.hostName}/base.md";
        basePrompt =
          [
            (lib.readFile ((lib.toString inputs.nix-secrets) + "/llm/prompts/base.md"))

            (lib.optionalString (lib.pathExists perHostPromptFile) (lib.readFile perHostPromptFile))
          ]
          |> lib.flatten
          |> lib.concatStringsSep "\n"
          |> (pkgs.writeText "base-prompt.md");
        genPrompts =
          [
            ".claude/CLAUDE.md"
            ".pi/SYSTEM_APPEND.md"
            ".omp/APPEND_SYSTEM.md"
            ".codex/AGENTS.md"
          ]
          |> map (path: {
            # "${path}".source =
            #   (lib.toString inputs.nix-secrets) + "/llm/prompts/${osConfig.networking.hostName}/base.md";
            "${path}".source = basePrompt;
          })
          |> lib.mergeAttrsList;
      in
      genPrompts;
  };

  # The two providers are on wireguard network together, so we use their ips
  ${namespace}.pi.providers = [
    {
      name = "ossa";
      host = vmSpecs.vm-lan.hosts.ossa.ip;
      port = vmSpecs.ports.tcp.llama-swap;
    }
    {
      name = "oedo";
      host = vmSpecs.vm-lan.hosts.oedo.ip;
      port = vmSpecs.ports.tcp.llama-swap;
    }
  ];

  programs = {
    zsh = {
      shellAliases = {
        # Restricted microvm with no LAN access, so should be okay
        "claude" = "claude --dangerously-skip-permissions";
      };
      # FIXME: These API keys should get abstracted by a proxy running on the host
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
