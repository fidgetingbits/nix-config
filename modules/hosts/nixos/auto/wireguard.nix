# Any locally managed system that is also roaming automatically gets setup for
# the VPN
{
  config,
  lib,
  namespace,
  ...
}:
{
  config = lib.mkIf (config.hostSpec.isLocal && config.hostSpec.isRoaming) {
    ${namespace}.wireguard =
      let
        net = config.hostSpec.networking;
        inherit (config.hostSpec) domain;
      in
      {
        enable = true;
        role = "client";
        peerNames = [ "ooze" ];
        allowedIPs = [
          net.wireguard.olan.subnet
          net.subnets.olan.cidr
        ];
        hosts = net.subnets.olan.hosts;
        endpoint = "vpn.${domain}";
        wireguardPort = net.ports.udp.wireguard;
        rosenpassPort = net.ports.udp.rosenpass;
        subnet = net.wireguard.olan.subnet;
        dns = {
          enable = true;
          server = net.subnets.olan.hosts.ogre.ip;
          inherit domain;
        };
      };
  };
}
