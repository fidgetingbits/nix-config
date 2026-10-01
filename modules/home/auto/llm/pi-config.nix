# FIXME: I guess this could just move to where we add pi?
{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.llm;

  jsonFormat = pkgs.formats.json { };
  formatPiProvider = provider: {
    baseUrl = provider.api_base;
    api = "openai-completions";
    apiKey = provider.api_key;
    models = provider.models;
  };

  models = {
    providers = lib.listToAttrs (
      map (provider: {
        name = provider.provider;
        value = formatPiProvider provider;
      }) cfg.providerModels
    );
  };

  modelsJson = jsonFormat.generate "pi-coding-agent-models.json" models;
in

{
  config = lib.mkIf (cfg.providers != [ ]) {
    home.file = {
      ".pi/agent/models.json".source = modelsJson;
      ".omp/agent/models.json".source = modelsJson;
    };
  };
}
