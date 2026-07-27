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
  subnet = net.subnets.o-lan;
  wg-subnet = subnet.wg-subnet;
  inherit (config.hostSpec)
    isLocal
    isRoaming
    hostName
    domain
    ;
in
{
  config = lib.mkIf (isLocal && isRoaming && (subnet.hosts.${hostName}.wireguardPubKey != "")) {
    ${namespace}.wireguard = {
      enable = true;
      role = "client";
      peers = [ subnet.hosts.ooze ];
      allowedIPs = [
        wg-subnet.cidr
        subnet.cidr
      ];
      endpoint = "vpn.${domain}";
      wireguardPort = net.ports.udp.wireguard;
      rosenpassPort = net.ports.udp.rosenpass;
      subnet = wg-subnet;
      dns = {
        enable = true;
        server = wg-subnet.dns;
        inherit domain;
      };
    };
  };
}
