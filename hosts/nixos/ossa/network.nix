# Example of a network to add to trustedNetworks:
#  my-network = {
#    type = "wireless";
#    ssid = "my-ssid";
#    interface = "wlo1";
#    gateway = "192.168.1.1";
#    mac = "aa:bb:cc:dd:ee:ff";
#  };
{
  lib,
  inputs,
  namespace,
  secrets,
  config,
  ...
}:
let
  # We already use wireguard for roaming connection to o-lan so need something else
  ports = config.hostSpec.networking.ports;
  hostName = config.networking.hostName;

  subnets = config.hostSpec.networking.subnets;
  wg-lan = subnets.agent-lan;
  o-lan = subnets.o-lan;
  inherit (lib.custom.network) triplet lastOctet;
  genWireguardIP = host: "${triplet wg-lan.cidr}.${lastOctet o-lan.hosts.${host}.ip}/32";
in
{
  networking.networkmanager.enable = true;

  ${namespace} = {
    cifs-mounts = {
      enable = true;
      sopsFile = (lib.toString inputs.nix-secrets) + "/sops/olan.yaml";
      mounts = [
        {
          name = "onus";
        }
        {
          name = "oath";
        }
      ];
    };
    services.per-network-services = {
      enable = true;
      debug = true;
      networkDevices = [ "wlp191s0" ];
      trustedNetworks = lib.flatten [
        secrets.networking.trusted.homeWifi
        secrets.networking.trusted.homeWired
      ];
    };
  };

  networking.granularFirewall.enable = true;

  # We have a microvm network connected with oedo via a wireguard tunnel
  # so that it stays up even when we are roaming
  #
  # Some secret stuff is already setup by the main wireguard module, since we are
  # re-using a key

  networking = {
    dhcpcd.denyInterfaces = [ "wg-microvms" ];
    wireguard = {
      interfaces = {
        wg-microvms = {
          privateKeyFile = config.sops.secrets."keys/wireguard/wgsk".path;
          ips = [ (genWireguardIP hostName) ];
          peers = [
            {
              name = "oedo";
              # FIXME: attr set entry is empty for some reason
              publicKey = "XwewD4/FElfpF5wV+qmmrhYBxQWL7tAjexwD916y9A8=";
              # o-lan.hosts.oedo.wireguardPubKey;
              allowedIPs = [
                subnets.agent-lan.cidr
                subnets.p-lan.cidr # oedo's microvm network
              ];
              endpoint = "${o-lan.hosts.oedo.ip}:${toString ports.udp.wireguard}";
              # Needed on clients for keeping NAT open
              persistentKeepalive = 25;
            }
          ];
        };
      };
    };
    nftables.ruleset = ''
      table inet vm_routing {
        chain forward {
          iifname "${config.${namespace}.microvms.vmBridge}" oifname "wg-microvms" accept
          iifname "wg-microvms" oifname "${config.${namespace}.microvms.vmBridge}" accept
        }
      }
    '';
  };
}
