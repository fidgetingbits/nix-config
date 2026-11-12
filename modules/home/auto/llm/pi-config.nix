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

  # Model id → harness-specific extras. Keyed by the alias/id served to clients.
  # Some stuff is harness specific, so not suited for the mkXXX functions. So we
  # just add it here
  extraSettings = {
    "Qwen 3.8 27B (Heavy)" = {
      reasoning = true;
      thinking = {
        mode = "effort";
        efforts = [
          "low"
          "medium"
          "xhigh"
        ];
      };
      compat = {
        supportsReasoningEffort = true;
        thinkingFormat = "qwen";
      };
    };
  };

  jsonFormat = pkgs.formats.json { };
  formatPiProvider =
    provider:
    let
      # Inject overrides for any model this provider serves that has extras
      modelOverrides = lib.filterAttrs (id: _: lib.elem id (map (m: m.id) provider.models)) extraSettings;
    in
    {
      baseUrl = provider.api_base;
      api = "openai-completions";
      apiKey = provider.api_key;
      discovery.type = "openai-models-list";
      # NOTE: Used to auto-generate this, but dynamic discovery
      # makes more sense unless we want to restrict what models
      # some microvms can use in the future or something
      # inherit (provider) models;
    }
    // lib.optionalAttrs (modelOverrides != { }) {
      inherit modelOverrides;
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
