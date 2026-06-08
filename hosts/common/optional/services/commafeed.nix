{
  config,
  lib,
  ...
}:
let
  servicePort = config.hostSpec.networking.ports.tcp.commafeed;
in
{
  services.commafeed = {
    enable = true;
  };

  services.nginxProxy.services = [
    {
      subDomain = "rss";
      extraDomains = [ "rss.${config.hostSpec.domain}" ];
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
          directory = "/var/lib/private/commafeed";
          user = "nobody";
          group = "nogroup";
          mode = "u=rwx,g=r-x,o=";
          # mode = "0700";
        }
      ];
    };
  };
}
