{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkOption types;
  servicePort = config.hostSpec.networking.ports.tcp.unifi-controller;
  cfg = config.services.unifi;
in
{
  options.services.unifi = {
    useProxy = mkOption {
      type = types.bool;
      default = true;
      description = "Expose service through nginx reverse proxy, with acme certs";
    };
  };
  config = {
    services.unifi = {
      enable = true;
      openFirewall = false; # Set to true if useProxy is false AND you won't managed remotely via ssh
      unifiPackage = pkgs.unifi;
      mongodbPackage = pkgs.mongodb-ce;
    };

    services.nginxProxy.services = mkIf cfg.useProxy [
      {
        subDomain = "unifi";
        port = servicePort;
      }
    ];

    environment = lib.optionalAttrs config.system.impermanence.enable {
      persistence = {
        "${config.hostSpec.persistFolder}".directories = [
          "/var/lib/unifi"
          "/var/log/unifi"
        ];
      };
    };

    # FIXME: Send a PR to expose ports used by packages inside the module itself somewhere?
    networking.firewall = {
      # https://help.ubnt.com/hc/en-us/articles/218506997
      allowedTCPPorts = [
        8080 # Port for UAP to inform controller.
      ];
    };
  };
}
