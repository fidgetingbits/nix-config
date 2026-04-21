{
  config,
  lib,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.wireguard;

  # FIXME: These could move to lib.custom.network, since they duplicate with ./default.nix
  subnetPrefix =
    ip:
    ip
    |> lib.splitString "."
    |> lib.take 3
    # nixfmt hack
    |> lib.concatStringsSep ".";
  lastOctet =
    ip:
    ip
    |> lib.splitString "."
    # nixfmt hack
    |> lib.last;
  genWireguardIP =
    host: "${subnetPrefix cfg.networkParams.subnet}.${lastOctet cfg.hosts.${host}.ip}/32";

  mkWireguardPeer = role: host: {
    publicKey = host.wgpk;
    allowedIPs = [ (genWireguardIP host.name) ];
  };
  mkWireguardPeers = role: hosts: (map (host: mkWireguardPeer role host) hosts);
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

    firewall.allowedUDPPorts = [
      cfg.networkParams.wireguardPort
      cfg.networkParams.rosenpassPort
    ];

    wireguard = {
      interfaces = {
        ${cfg.interface} = {
          peers =
            cfg.peerNames
            |> map (name: cfg.hosts.${name})
            # nixfmt hack
            |> mkWireguardPeers cfg.role;
        };
      };
    };
  };

  # See ./default.nix for base settings
  services.rosenpass.settings.listen = [ "0.0.0.0:${toString cfg.networkParams.rosenpassPort}" ];

  assertions = [
    {
      assertion = cfg.allowedIPs == null;
      message = "The allowedIPs option shouldn't be set for the server, as it is automatically configured using cfg.hosts";
    }
  ];
}
