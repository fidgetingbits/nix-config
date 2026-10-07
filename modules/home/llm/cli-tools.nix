{
  config,
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
      };

      file = {
        ".config/fabric/.env".text = ''
          DEFAULT_MODEL=${llmCfg.defaultModel}
          OPENAI_BASE_URL=http://${defaultProvider.name}:${toString defaultProvider.port}/v1
          CUSTOM_PATTERNS_DIRECTORY="${config.programs.fabric-ai.package.src}/data/patterns"
          PATTERNS_LOADER_GIT_REPO_URL="https://github.com/danielmiessler/fabric.git"
          PATTERNS_LOADER_GIT_REPO_PATTERNS_FOLDER="patterns"
        '';
        ".config/fabric/openai_api_key".text = "foo";
        ".config/fabric/patterns/.keep".text = "# Managed by Home Manager";
      };
    };

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
