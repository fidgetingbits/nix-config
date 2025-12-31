{ config, lib, ... }:
{
  options.services.nginxProxy = {
    services = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            subDomain = lib.mkOption {
              type = lib.types.str;
              description = "Sub-domain name for the proxy";
            };
            port = lib.mkOption {
              type = lib.types.port;
              description = "Local port to proxy to";
            };
            ssl = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Use SSL";
            };
            extraConfig = lib.mkOption {
              type = lib.types.attrsOf lib.types.anything;
              default = { };
              description = "Extra nginx location configuration";
            };
          };
        }
      );
      default = [ ];
      description = ''
        List of services to proxy using nginx.virtualhosts, each service has an
        ACME certificate generated for the subdomain.
      '';
    };
  };

  config =
    let
      cfg = config.services.nginxProxy;
    in
    {
      services.nginx.virtualHosts = lib.mkMerge (
        map (
          service:
          let
            domain = "${service.subDomain}.${config.hostSpec.hostName}.${config.hostSpec.domain}";
            uri = if service.ssl then "https" else "http";
          in
          {
            "${domain}" = {
              listenAddresses = [ "0.0.0.0" ];
              onlySSL = true;
              useACMEHost = domain;
              locations."/" = {
                recommendedProxySettings = true;
                proxyPass = "${uri}://127.0.0.1:${toString service.port}";
              }
              // service.extraConfig;
            };
          }
        ) cfg.services
      );

      security.acme.certs = lib.mkMerge (
        map (
          service:
          let
            domain = "${service.subDomain}.${config.hostSpec.hostName}.${config.hostSpec.domain}";
          in
          {
            "${domain}" = {
              inherit domain;
              group = config.services.nginx.group;
            };
          }
        ) cfg.services
      );
    };
}
