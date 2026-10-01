# Configuration for https://github.com/simonw/llm, a python cli tool for calling models
# Originally from https://github.com/EricCrosson/dotfiles/blob/3230246e6d782e8e3cd6decf809d9ac6b2c845b4/modules/home-manager/programs/llm/default.nix
{
  pkgs,
  lib,
  config,
  namespace,
  ...
}:
let
  cfg = config.programs.llm;
  llmCfg = config.${namespace}.llm;
  localProviders = config.${namespace}.llm.providerModels;
  yamlFormat = pkgs.formats.yaml { };
  jsonFormat = pkgs.formats.json { };

  modelToAttrs = model: {
    model_id = model.id;
    model_name = model.name;
    api_base = model.api_base;
  };

  # Convert our local provider model format into llm config format
  genLocalModels =
    provider:
    map (model: {
      # Use a unique model_id so models across multiple llama-swap servers don't clash
      model_id = "${provider.provider}/${model.id}";
      model_name = model.name;
      inherit (provider) api_base;
      api_key_name = provider.provider;
    }) provider.models;

  localModels = lib.concatMap genLocalModels localProviders;
  allModels = localModels ++ (map modelToAttrs cfg.extraModels);

  extraModelSubmodule = lib.types.submodule {
    options = {
      id = lib.mkOption {
        type = lib.types.str;
        description = "Unique model identifier in llm CLI";
        example = "openrouter/claude-3.5-sonnet";
      };

      name = lib.mkOption {
        type = lib.types.str;
        description = "Full model name required by the target API endpoint";
        example = "anthropic/claude-3.5-sonnet";
      };

      api_base = lib.mkOption {
        type = lib.types.str;
        description = "Base API URL endpoint";
        example = "https://openrouter.ai/api/v1";
      };

      api_key_name = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Key name stored using `llm keys set` or an environment variable";
        example = "OPENROUTER_API_KEY";
      };
    };
  };
in
{
  options.programs.llm = {
    enable = lib.mkEnableOption "LLM CLI configuration";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.unstable.llm;
      defaultText = lib.literalExpression "pkgs.llm";
      description = "The LLM package to use.";
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      default = ".config/io.datasette.llm";
      description = "Directory for LLM configuration files (relative to home directory)";
      readOnly = true;
    };

    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "${llmCfg.defaultProvider}/${llmCfg.defaultModel}";
      description = "Default local model to use";
    };

    extraModels = lib.mkOption {
      type = lib.types.listOf extraModelSubmodule;
      default = [ ];
      description = "Extra models in addition to auto-generated local models";
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      file = {
        "${cfg.configDir}/default_model.txt".text = cfg.defaultModel;
        "${cfg.configDir}/extra-openai-models.yaml".source =
          yamlFormat.generate "llm-extra-openai-models.yaml" allModels;
        "${cfg.configDir}/keys.json".source = jsonFormat.generate "keys.json" (
          localProviders
          |> map (p: {
            ${p.provider} = p.api_key;
          })
          |> lib.mergeAttrsList
        );
      };

      packages = [ cfg.package ];
      sessionVariables = {
        LLM_USER_PATH = "${config.home.homeDirectory}/${cfg.configDir}";
      };
    };
  };
}
