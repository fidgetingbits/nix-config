# Generate local llm provider lists
{
  config,
  lib,
  namespace,
  inputs,
  ...
}:
let
  cfg = config.${namespace}.llm;

  providerSubmodule = lib.types.submodule {
    options = {
      provider = lib.mkOption {
        type = lib.types.str;
        description = "Provider/host identifier";
      };
      api_base = lib.mkOption {
        type = lib.types.str;
        description = "Base API URL endpoint";
      };
      api_key = lib.mkOption {
        type = lib.types.str;
        default = "foo";
        description = "API Key or dummy string";
      };
      models = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              id = lib.mkOption { type = lib.types.str; };
              name = lib.mkOption { type = lib.types.str; };
            };
          }
        );
        default = [ ];
        description = "Models provided by provider";
      };
    };
  };

  # Read llama-swap config from inputs and return a list with 1 provider submodule attrset
  genLocalModels =
    {
      name,
      host,
      port,
    }:
    let
      mkModel = id: name: { inherit id name; };
      rawModels = inputs.self.nixosConfigurations.${name}.config.services.llama-swap.settings.models;
    in
    [
      {
        provider = name;
        api_base = "http://${host}:${toString port}/v1";
        api_key = "foo";
        models = lib.mapAttrsToList (k: v: mkModel k k) rawModels;
      }
    ];

in
{
  options.${namespace}.llm = {
    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "Ornith 1.5-35b-a3b";
      example = "foo";
      description = "The default model to use in tools. See llama-swap for list";
    };

    defaultProvider = lib.mkOption {
      type = lib.types.str;
      default = "oedo";
      example = "foo";
      description = "The default host running llama-swap to use the model on";
    };
    providers = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption { type = lib.types.str; };
            host = lib.mkOption { type = lib.types.str; };
            port = lib.mkOption { type = lib.types.port; };
          };
        }
      );
      default = [ ];
      description = "List of local llama-swap providers to track";
    };

    providerModels = lib.mkOption {
      type = lib.types.listOf providerSubmodule;
      default = lib.concatMap genLocalModels cfg.providers;
      internal = true;
      visible = false;
      readOnly = true;
      description = "Internal list of LLM models aggregated from local providers";
    };
  };
}
