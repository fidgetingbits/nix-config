{
  config,
  lib,
  pkgs,
  ...
}:
let
  servicePort = config.hostSpec.networking.ports.tcp.unifi-controller;
in
{
  services.unifi = {
    enable = true;
    openFirewall = false;
    unifiPackage = pkgs.unifi;
    mongodbPackage = pkgs.mongodb-ce;
  };

  services.nginxProxy.services = [
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
}
