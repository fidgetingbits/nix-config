{
  lib,
  config,
  inputs,
  ...
}:
let
  sopsFolder = (lib.toString inputs.nix-secrets) + "/sops";
  ports = config.hostSpec.networking.ports;
in
{
  services.librechat = {
    enable = true;
    enableLocalDB = true;
    env = {
      HOST = "127.0.0.1";
      PORT = ports.tcp.librechat;
      # DOMAIN_CLIENT = "librechat.${config.networking.hostName}.${config.hostSpec.domain}";
      # DOMAIN_SERVER = "librechat.${config.networking.hostName}.${config.hostSpec.domain}";
      # ALLOW_REGISTRATION = "true";
    };
    credentials = {
      CREDS_KEY = config.sops.secrets."librechat/creds-key".path;
      CREDS_IV = config.sops.secrets."librechat/creds-iv".path;
      JWT_SECRET = config.sops.secrets."librechat/jwt-secret".path;
      JWT_REFRESH_SECRET = config.sops.secrets."librechat/jwt-refresh-secret".path;
      MEILI_MASTER_KEY = config.sops.secrets."librechat/meili-master-key".path;
      OPENROUTER_API_KEY = config.sops.secrets."tokens/openrouter".path;
    };
    settings = {
      version = "1.3.13"; # https://www.librechat.ai/changelog/
      endpoints = {
        custom = [
          {
            name = "oedo";
            apiKey = "foo";
            baseURL = "http://oedo.${config.hostSpec.domain}:${toString ports.tcp.llama-swap}/v1";
            models = {
              default = [ "Qwen 3.6 Coder 30B (Light)" ];
              fetch = false;
            };
            titleConvo = true;
            titleModule = "meta-llama/llama-3-70b-instruct";
            modelDisplayLabel = "oedo";
          }
          {
            name = "OpenRouter";
            apiKey = "\${OPENROUTER_API_KEY}";
            baseURL = "https://openrouter.ai/api/v1";
            models = {
              default = [ "meta-llama/llama-3-70b-instruct" ];
              fetch = true;
            };
            titleConvo = true;
            titleModule = "meta-llama/llama-3-70b-instruct";
            dropParams = [ "stop" ];
            modelDisplayLabel = "OpenRouter";
          }
        ];
      };
    };
  };

  # https://www.librechat.ai/docs/toolkit/credentials-generator
  sops.secrets =
    (
      [
        "librechat/creds-key"
        "librechat/creds-iv"
        "librechat/jwt-secret"
        "librechat/jwt-refresh-secret"
        "librechat/meili-master-key"
      ]
      |> lib.map (entry: {
        "${entry}" = {
          sopsFile = "${sopsFolder}/librechat.yaml";
        };
      })
      |> lib.mergeAttrsList
    )
    // {
      "tokens/openrouter" = {
        sopsFile = "${sopsFolder}/agents.yaml";
      };
    };

  environment = lib.optionalAttrs config.introdus.impermanence.enable {
    persistence."${config.hostSpec.persistFolder}" = {
      directories = [
        config.services.librechat.dataDir
      ];
    };
  };

  services.nginxProxy.services = [
    {
      subDomain = "librechat"; # Creates librechat.host.domain
      # extraDomains = [ "search.${config.hostSpec.domain}" ];
      port = ports.tcp.librechat;
      ssl = false;
    }
  ];
}
