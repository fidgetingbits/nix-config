{
  config,
  namespace,
  lib,
  inputs,
  ...
}:
let
  net = config.hostSpec.networking;
  subnet = net.subnets.o-lan;
  wg-subnet = net.subnets.wg-olan;
  inherit (config.hostSpec)
    domain
    ;

  secretsFolder = lib.toString inputs.nix-secrets;
  sopsFolder = secretsFolder + "/sops/";
  hostName = config.networking.hostName;
  wg-if = config.${namespace}.wireguard.interface;
in
{
  ${namespace}.wireguard = {
    enable = true;
    role = "client";
    peers = [ subnet.hosts.ooze ];
    allowedIPs = [
      wg-subnet.cidr
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

  networking.wireguard.interfaces.${wg-if}.ips = lib.mkForce [
    "${wg-subnet.hosts.moon.ip}/32"
  ];

  networking.hosts = {
    "${wg-subnet.hosts.ooze.ip}" = [ "photos.${domain}" ];
  };

  # FIXME: This should just already be part of using the wireguard module no?
  # Also an issue on ooze
  sops.secrets = {
    "keys/wireguard/wgsk" = {
      sopsFile = "${sopsFolder}/${hostName}.yaml";
    };
  };
}
