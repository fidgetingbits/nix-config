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
        olan = net.subnets.olan;
      in
      {
        enable = true;
        role = "client";
        peerNames = [ "ooze" ];
        allowedIPs = [
          olan.wireguard.subnet
          olan.cidr
        ];
        hosts = net.subnets.olan.hosts;
        endpoint = "vpn.${domain}";
        wireguardPort = net.ports.udp.wireguard;
        rosenpassPort = net.ports.udp.rosenpass;
        subnet = olan.wireguard.subnet;
        dns = {
          enable = true;
          server = net.subnets.olan.hosts.ogre.ip;
          inherit domain;
        };
      };
  };
}
