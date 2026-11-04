{
  config,
  osConfig,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  llmCfg = config.${namespace}.llm;
  cfg = config.${namespace}.llm.cli-tools;
  # FIXME: Would be nicer if we could just index by name...
  defaultProvider = lib.findFirst (p: p.name == llmCfg.defaultProvider) null llmCfg.providers;

  # Populate fabric patterns from: official source, local repo, private repo
  mergedPatterns = pkgs.symlinkJoin {
    name = "merged-fabric-patterns";
    paths = [
      "${config.programs.fabric-ai.package.src}/data/patterns" # Default patterns from Nix pkg
      # ./XXX                   # Public patterns
      # inputs.nix-secrets.XXX  # Secret patterns
    ];
  };
in
{
  options.${namespace}.llm.cli-tools = {
    enable = lib.mkEnableOption "Enable AI client cli tooling";
  };

  config = lib.mkIf cfg.enable {
    home = {
      packages = lib.attrValues {
        inherit (pkgs.unstable)
          llama-cpp
          ;
        inherit (pkgs.unstable.python3Packages)
          huggingface-hub # hf cli tool
          ;
      };

      file = {
        ".config/fabric/.env".text = ''
          DEFAULT_MODEL="${llmCfg.defaultModel}"
          DEFAULT_VENDOR="OpenAI"
          OPENAI_API_BASE_URL="https://llm.${defaultProvider.name}.${osConfig.hostSpec.domain}/v1"
          CUSTOM_PATTERNS_DIRECTORY="${config.home.homeDirectory}/.config/fabric/patterns"
          PATTERNS_LOADER_GIT_REPO_URL="https://github.com/danielmiessler/fabric.git"
          PATTERNS_LOADER_GIT_REPO_PATTERNS_FOLDER="patterns"
        '';
        ".config/fabric/openai_api_key".text = "foo";
        ".config/fabric/patterns/.keep".text = "# Managed by Home Manager";
      };
    };

    home.activation.setupFabricPatterns = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      target="${config.home.homeDirectory}/.config/fabric/patterns"
      source="${mergedPatterns}"

      mkdir -p "$target"

      # Clear out any store-backed symlinks so they always refresh to current pattern set
      for item in "$target"/*; do
        if [ -L "$item" ]; then
          case "$(readlink "$item" || true)" in
            /nix/store/*) rm "$item" ;;
          esac
        fi
      done

      # Link all patterns
      if [ -d "$source" ]; then
        for item in "$source"/*; do
          name=$(basename "$item")
          dest="$target/$name"
          if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
            ln -s "$item" "$dest"
          fi
        done
      fi
    '';

    programs = {
      # python cli tool for quick prompt-based outputs
      #  see ./llm-cli.nix
      llm = {
        enable = true;
      };

      # unix-style cli tool focusing on builtin patterns (prompts)
      fabric-ai = {
        enable = true;
        package = pkgs.unstable.fabric-ai;
        enableZshIntegration = true;
        # enablePatternsAliases = true;
      };
    };

  };

}
