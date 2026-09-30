{
  inputs,
  config,
  lib,
  ...
}:

let
  inherit (lib) mkIf mkOption types;
  servicePort = config.hostSpec.networking.ports.tcp.anki-sync-server;
  cfg = config.services.anki-sync-server;
  sopsFolder = (lib.toString inputs.nix-secrets) + "/sops";
in
{
  options.services.anki-sync-server = {
    useProxy = mkOption {
      type = types.bool;
      default = true;
      description = "Expose service through nginx reverse proxy, with acme certs";
    };
  };
  config = {

    sops.secrets = {
      "passwords/anki" = {
        sopsFile = "${sopsFolder}/${config.hostSpec.hostName}.yaml";
      };
    };
    services.anki-sync-server = {
      enable = true;
      address = "127.0.0.1";
      port = config.hostSpec.networking.ports.tcp.anki-sync-server;
      users = [
        {
          username = config.hostSpec.primaryUsername;
          passwordFile = config.sops.secrets."passwords/anki".path;
        }
      ];
    };

    services.nginxProxy.services = mkIf cfg.useProxy [
      {
        subDomain = "anki";
        port = servicePort;
        ssl = false;
      }

    ];

    environment = lib.optionalAttrs config.introdus.impermanence.enable {
      persistence = {
        "${config.hostSpec.persistFolder}".directories = [
          {
            directory = "/var/lib/private/anki-sync-server";
            user = "nobody";
            group = "nogroup";
          }
        ];
      };
    };
  };

}
