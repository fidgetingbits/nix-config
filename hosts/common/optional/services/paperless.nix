{
  config,
  lib,
  ...
}:
let
  servicePort = config.hostSpec.networking.ports.tcp.paperless;

  domain = config.hostSpec.domain;
  hostnames = [
    "paperless.${domain}"
    "paperless.${config.networking.hostName}.${domain}"
  ];
  hostnamesWithSchema = map (host: "https://${host}") hostnames;
in
{
  # FIXME: set up declarative admin user like https://github.com/pschmitt/nixos-config/blob/08b45c88b26487a9d622393defc51fce3c6e81cd/services/paperless-ngx.nix#L105

  services.paperless = {
    enable = true;
    database.createLocally = false; # We already have postgres setup on ooze
    port = servicePort;

    # https://docs.paperless-ngx.com/configuration/
    settings = {
      # Prevent django CSRF errors on setup
      PAPERLESS_CSRF_TRUSTED_ORIGINS = lib.concatStringsSep "," hostnamesWithSchema;
    };
  };

  services.nginxProxy.services = [
    {
      subDomain = "paperless";
      port = servicePort;
      ssl = false;
      extraLocationSettings = {
        proxyWebsockets = true;
      };
    }
  ];

  environment = lib.optionalAttrs config.introdus.impermanence.enable {
    persistence = {
      "${config.hostSpec.persistFolder}".directories = [
        {
          directory = "/var/lib/private/paperless";
          user = "nobody";
          group = "nogroup";
          mode = "u=rwx,g=r-x,o=";
          # mode = "0700";
        }
      ];
    };
  };
}
