{
  config,
  lib,
  ...
}:
let
  servicePort = config.hostSpec.networking.ports.tcp.calibre;
in
{
  services.calibre-web = {
    enable = true;
    listen.ip = "0.0.0.0";
    listen.port = servicePort;
    options.enableBookUploading = true;
    options.enableBookConversion = true;
    options.enableKepubify = true;
  };

  services.nginxProxy.services = [
    {
      subDomain = "books";
      extraDomains = [ "books.${config.hostSpec.domain}" ];
      port = servicePort;
      ssl = false;
      extraSettings = {
        proxyWebsockets = true;
        extraConfig = ''
          client_max_body_size 50000M;
          proxy_read_timeout   600s;
          proxy_send_timeout   600s;
          send_timeout         600s;
        '';
      };
    }
  ];

  environment = lib.optionalAttrs config.introdus.impermanence.enable {
    persistence = {
      "${config.hostSpec.persistFolder}".directories = [
        {
          directory = "/var/lib/calibre-web";
          user = "calibre-web";
          group = "calibre-web";
          mode = "u=rwx,g=rwx,o=";
        }
      ];
    };
  };
}
