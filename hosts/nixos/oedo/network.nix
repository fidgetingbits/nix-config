{
  inputs,
  config,
  lib,
  namespace,
  ...
}:
let
  secretsFolder = lib.toString inputs.nix-secrets;
  sopsFolder = secretsFolder + "/sops/";
  hostName = config.networking.hostName;
  wireguardPort = 51820;

  subnets = config.hostSpec.networking.subnets;
  wg-lan = subnets.agent-lan;
  o-lan = subnets.o-lan;
  inherit (lib.custom.network) triplet lastOctet;
  genWireguardIP = host: "${triplet wg-lan.cidr}.${lastOctet o-lan.hosts.${host}.ip}/32";
in
{
  # We run a wireguard server that exposes access to the microvms to ossa/opia. It
  # also allows connectivity between the microvms on oedo and ossa. Unlike wireguard
  # for remote o-lan access, I don't use rosenpass for this.

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };

  networking = {
    firewall = {
      allowedUDPPorts = [
        wireguardPort
      ];
    };

    wireguard = {
      interfaces = {
        wg-microvms = {
          listenPort = wireguardPort;
          privateKeyFile = config.sops.secrets."keys/wireguard/wgsk".path;
          ips = [ (genWireguardIP hostName) ];
          peers = [
            {
              name = "ossa";
              publicKey = o-lan.hosts.ossa.wireguardPubKey;
              allowedIPs = [
                (genWireguardIP "ossa")
                subnets.n-lan.cidr # Ossa's microvms
              ];
            }
            {
              name = "opia";
              publicKey = o-lan.hosts.opia.wireguardPubKey;
              allowedIPs = [
                (genWireguardIP "opia")
              ];
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

  sops.secrets = {
    "keys/wireguard/wgsk" = {
      sopsFile = "${sopsFolder}/${hostName}.yaml";
    };
  };

  # FIXME: Not sure this is needed, but living from wireguard/default.nix
  systemd.services.wireguard-wg-microvms = {
    preStart = ''
      echo "Waiting for default network gateway..."
      until ip route show default | grep -q default; do
        sleep 1
      done
      echo "Gateway found, proceeding."
    '';
  };
}
