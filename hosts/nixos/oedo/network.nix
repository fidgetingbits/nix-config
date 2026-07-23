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

  ports = config.hostSpec.networking.ports;
  subnets = config.hostSpec.networking.subnets;
  wg-lan = subnets.agent-lan;
  o-lan = subnets.o-lan;
  inherit (lib.custom.network) triplet lastOctet;
  genWireguardIP = host: "${triplet wg-lan.cidr}.${lastOctet o-lan.hosts.${host}.ip}/32";
  vmBridge = config.${namespace}.microvms.vmBridge;
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

        # Need explicit rules for now. Mark is handled by nixos-fw injection
        chain input {
          type filter hook input priority filter - 5; policy accept;
          iifname "wg-microvms" ip saddr ${subnets.n-lan.cidr} tcp dport ${toString ports.tcp.llama-swap} meta mark set 0x00000001
        }
      }

    '';
  };

  # We need to inject a routing policy to avoid the vpn that may be running on the microvm
  # FIXME: could just loop over every host we want to share the vm network for?
  # NOTE: This is duplicated with oedo, so could put somewhere shared
  systemd.network.networks."20-${vmBridge}".routingPolicyRules = [
    {
      From = config.${namespace}.microvms.vmLan.cidr;
      To = inputs.self.nixosConfigurations.ossa.config.${namespace}.microvms.vmLan.cidr;
      Table = "main";
      Priority = 998;
    }
    {
      From = config.${namespace}.microvms.vmLan.cidr;
      To = config.hostSpec.networking.subnets.agent-lan.cidr;
      Table = "main";
      Priority = 998;
    }
  ];

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
