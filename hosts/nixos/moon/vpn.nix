{
  config,
  namespace,
  lib,
  inputs,
  ...
}:
let
  net = config.hostSpec.networking;

  inherit (lib.custom.network) lastOctet;
  subnet = net.subnets.o-lan;
  wg-subnet = net.subnets.wg-olan;
  inherit (config.hostSpec)
    domain
    ;

  secretsFolder = lib.toString inputs.nix-secrets;
  sopsFolder = secretsFolder + "/sops/";
  hostName = config.networking.hostName;

  inherit (lib.custom.network) triplet;
  genWireguardIP = subnet: suffix: "${triplet subnet.cidr}.${toString suffix}/32";
in
{
  ${namespace}.wireguard = {
    enable = true;
    role = "client";
    peerNames = [ "ooze" ];
    allowedIPs = [
      wg-subnet.cidr
    ];

    hosts = subnet.hosts // net.subnets.moon.hosts;
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

  # FIXME: Hack, because we don't control moon's IP, we can't use the normal lastOctet generation
  # Might be nice to have an override in the options or something
  networking.wireguard.interfaces.wg0.ips = lib.mkForce [
    (genWireguardIP net.subnets.o-lan.wg-subnet 100)
  ];

  networking.hosts = {
    "${triplet wg-subnet.cidr}.${lastOctet subnet.hosts.ooze.ip}" = [ "photos.${domain}" ];
  };

  # FIXME: This should just already be part of using the wireguard module no?
  # Also an issue on ooze
  sops.secrets = {
    "keys/wireguard/wgsk" = {
      sopsFile = "${sopsFolder}/${hostName}.yaml";
    };
  };
}
