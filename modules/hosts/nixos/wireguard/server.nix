{
  config,
  lib,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.wireguard;
  inherit (lib.custom.network) mkWireguardPeers;
in
lib.mkIf (cfg.enable && cfg.role == "server") {
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };
  networking = {
    nat = {
      enable = true;
      enableIPv6 = false;
      internalInterfaces = [ cfg.interface ];
      inherit (cfg) externalInterface;
    };

    firewall = {
      allowedUDPPorts = [
        cfg.wireguardPort
        cfg.rosenpassPort
      ];
    };

    wireguard = {
      interfaces = {
        ${cfg.interface} = {
          peers = mkWireguardPeers cfg.peers;
        };
      };
    };
  };

  # See ./default.nix for base settings
  services.rosenpass.settings.listen = [ "0.0.0.0:${toString cfg.rosenpassPort}" ];

  assertions = [
    {
      assertion = cfg.allowedIPs == null;
      message = "The allowedIPs option shouldn't be set for the server, as it is automatically configured using peers";
    }
    {
      assertion = cfg.endpoint == null;
      message = "The endpoint option shouldn't be set for a server.";
    }
  ];
}
