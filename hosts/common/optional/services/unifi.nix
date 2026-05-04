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
      unifiPackage = pkgs.unstable.unifi;
      # https://github.com/NixOS/nixpkgs/pull/511607/changes/7685a643866bab316d6fdde455a0c44d3702bfa9
      # FIXME: This should be default as of 26.05
      jrePackage = pkgs.jdk25_headless;
      mongodbPackage = pkgs.mongodb-ce;
    };

    services.nginxProxy.services = mkIf cfg.useProxy [
      {
        subDomain = "unifi";
        port = servicePort;
      }
    ];

    environment = lib.optionalAttrs config.introdus.impermanence.enable {
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
