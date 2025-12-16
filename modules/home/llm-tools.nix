{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.llm-tools;
  zshCfg = config.programs.zsh;
  server = "oedo.${config.hostSpec.domain}";
  port = config.hostSpec.networking.ports.tcp.llama-swap;
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
        pkgs.llama-cpp # offline inference (llama, deepseek, qwen, etc)
        pkgs.ollama
      ];

      sessionVariables = {
        OLLAMA_HOST = server;
        OLLAMA_API_URL = server;
      };

    };

    # online inference (llama-swap, claude, gemini, openai, etc)
    programs.llm =
      let
        api_base = "http://${server}:${toString port}/v1";
      in
      {
        enable = true;
        # FIXME: This should auto-add our llama-swap models somehow
        defaultModel = "ds-small";
        models = [
          {
            name = "ds-big";
            id = "ds-big";
            inherit api_base;
          }
          {
            name = "ds-small";
            id = "ds-small";
            inherit api_base;
          }
        ];
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
