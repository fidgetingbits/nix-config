{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.llm-tools;
  zshCfg = config.programs.zsh;
in
{
  options = {
    llm-tools = {
      enable = lib.mkEnableOption "Enable AI client tooling";
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      packages = [
        pkgs.llm # online inference (llama-swap, claude, gemini, openai, etc)
        pkgs.llama-cpp # offline inference (llama, deepseek, qwen, etc)
        pkgs.ollama
      ];

      sessionVariables = {
        OLLAMA_HOST = "oedo.${config.hostSpec.domain}";
        OLLAMA_API_URL = "oedo.${config.hostSpec.domain}";
      };

    };
    programs.zsh.shellAliases = lib.mkIf zshCfg.enable {
      ol = "ollama";
      oli = "ollama info";
      olpl = "ollama pull";
      olps = "ollama ps";
      oll = "ollama ls";
      olrm = "ollama rm";
      olr = "ollama run";
      ols = "ollama stop";
      olh = "ollama --help";
    };
  };
}
