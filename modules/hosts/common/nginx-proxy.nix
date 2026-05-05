{ config, lib, ... }:
{
  options.services.nginxProxy = {
    services = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            subDomain = lib.mkOption {
              type = lib.types.str;
              description = ''
                Sub-domain name for the proxy. By default uses: ''${subDomain}.''${hostname}.''${domain}.
                For additional domains, use cfg.extraDomains
              '';
            };
            extraDomains = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              example = [ "foo.example.com" ];
              description = ''
                List of additional subdomains that are mapped in addition to the normal ''${subDomain}.''${hostname}.''${domain}.
                This allows you to say have git.example.com, in addition to the default git.serverName.example.com
              '';
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
            extraSettings = lib.mkOption {
              type = lib.types.attrsOf lib.types.anything;
              default = { };
              description = "Extra nginx location settings and configuration";
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
        lib.concatMap (
          service:
          let
            domains = [
              "${service.subDomain}.${config.hostSpec.hostName}.${config.hostSpec.domain}"
            ]
            ++ service.extraDomains;
            uri = if service.ssl then "https" else "http";
          in
          map (domain: {
            "${domain}" = {
              listenAddresses = [ "0.0.0.0" ];
              onlySSL = true;
              useACMEHost = domain;
              locations."/" = {
                recommendedProxySettings = true;
                proxyPass = "${uri}://127.0.0.1:${toString service.port}";
              }
              // service.extraSettings;
            };
          }) domains
        ) cfg.services
      );

      security.acme.certs = lib.mkMerge (
        lib.concatMap (
          service:
          let
            domains = [
              "${service.subDomain}.${config.hostSpec.hostName}.${config.hostSpec.domain}"
            ]
            ++ service.extraDomains;
          in
          map (domain: {
            "${domain}" = {
              inherit domain;
              group = config.services.nginx.group;
            };
          }) domains
        ) cfg.services
      );
    };
}
