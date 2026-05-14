# Any locally managed system that is also roaming automatically gets setup for
# the VPN
{
  config,
  lib,
  namespace,
  ...
}:
let
  net = config.hostSpec.networking;

  # FIXME: Somehow check "home" LAN of a host rather than hardcode
  subnet = net.subnets.olan;
  inherit (config.hostSpec)
    isLocal
    isRoaming
    hostName
    domain
    ;
in
{
  config = lib.mkIf (isLocal && isRoaming && (subnet.hosts.${hostName}.wgpk != "")) {
    ${namespace}.wireguard = {
      enable = true;
      role = "client";
      peerNames = [ "ooze" ];
      allowedIPs = [
        subnet.wireguard.subnet
        subnet.cidr
      ];
      hosts = subnet.hosts;
      endpoint = "vpn.${domain}";
      wireguardPort = net.ports.udp.wireguard;
      rosenpassPort = net.ports.udp.rosenpass;
      subnet = subnet.wireguard.subnet;
      dns = {
        enable = true;
        server = subnet.hosts.ogre.ip;
        inherit domain;
      };
    };
  };
}
