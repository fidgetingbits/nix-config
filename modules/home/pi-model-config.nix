{
  pkgs,
  config,
  lib,
  namespace,
  inputs,
  ...
}:
let
  cfg = config.${namespace}.pi;
in
{
  options.${namespace}.pi = {
    providers = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [ ];
      description = "Local LLM providers to add to pi.dev's models.json";
    };
  };

  config =
    let
      jsonFormat = pkgs.formats.json { };
      # yamlFormat = pkgs.formats.yaml { };
      mkModel = id: name: { inherit id name; };
      genModels =
        {
          name,
          host,
          port,
        }:
        let
          models = inputs.self.nixosConfigurations.${name}.config.services.llama-swap.settings.models;
        in
        {
          ${name} = {
            baseUrl = "http://${host}:${toString port}/v1";
            api = "openai-completions";
            apiKey = "foo";
            models = lib.mapAttrsToList (k: v: mkModel k k) models;
          };
        };
      models.providers = lib.mergeAttrsList (map (provider: genModels provider) cfg.providers);
      modelsJson = jsonFormat.generate "pi-coding-agent-models.json" models;
    in
    lib.mkIf ((lib.length cfg.providers) != 0) {
      home.file = {
        ".pi/agent/models.json".source = modelsJson;
        # FIXME: omp uses yaml by default I think, so could switch
        ".omp/agent/models.json".source = modelsJson;
      };
    };
}
