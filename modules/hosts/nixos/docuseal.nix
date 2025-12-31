# FIXME: This needs to assert nginx is enabled if using proxy
{
  inputs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkOption types;
  servicePort = config.hostSpec.networking.ports.tcp.docuseal;
  cfg = config.services.docuseal;
  sopsFolder = (builtins.toString inputs.nix-secrets) + "/sops";
in
{
  # imports = [ ./nginx.nix ];

  options.services.docuseal = {
    useProxy = mkOption {
      type = types.bool;
      default = true;
      description = "Expose service through nginx reverse proxy, with acme certs";
    };
  };
  config = lib.mkIf cfg.enable {
    sops.secrets = {
      "keys/docuseal" = {
        sopsFile = "${sopsFolder}/${config.hostSpec.hostName}.yaml";
      };
    };
    # FIXME: Should send a PR to docuseal to fix LoadCredential
    systemd.services.docuseal.serviceConfig.LoadCredential = "docusealSecret:${
      config.sops.secrets."keys/docuseal".path
    }";
    services.docuseal = {
      # NOTE: Trying to use /%d crashed ruby. Normally you'd %d/... but
      # docuseal option wants a full path, so tried anyway
      #secretKeyBaseFile = "/%d/docusealSecret";
      secretKeyBaseFile = "/run/credentials/docuseal.service/docusealSecret";
    };

    services.nginxProxy.services = mkIf cfg.useProxy [
      {
        subDomain = "docuseal";
        port = servicePort;
        ssl = false;
      }
    ];

    environment = lib.optionalAttrs config.system.impermanence.enable {
      persistence = {
        "${config.hostSpec.persistFolder}".directories = [
          {
            directory = "/var/lib/private/docuseal";
            user = "nobody";
            group = "nogroup";
          }
          {
            directory = "/var/log/private/docuseal";
            user = "nobody";
            group = "nogroup";
          }
        ];
      };
    };
  };
}
