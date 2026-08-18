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
  vmBridge = config.${namespace}.microvms.vmBridge;
  oedoConfig = inputs.self.nixosConfigurations.oedo.config;
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
          ips = [ "${wg-lan.hosts.${hostName}.ip}/32" ];
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
          iifname "${vmBridge}" oifname "wg-microvms" accept
          iifname "wg-microvms" oifname "${vmBridge}" accept
        }

        # Need explicit rules for now. Mark is handled by nixos-fw injection
        # FIXME: Switch to genAllowRemoteInputs style thing for either VM, so this can auto generate...
        chain input {
          type filter hook input priority filter - 5; policy accept;
          iifname "wg-microvms" ip saddr ${subnets.p-lan.cidr} tcp dport ${toString ports.tcp.llama-swap} meta mark set 0x00000001
        }
      }
    '';
  };

  # We need to inject a routing policy to avoid the vpn
  # NOTE: This is duplicated with oedo, so could put somewhere shared
  systemd.network.networks."20-${vmBridge}".routingPolicyRules = [
    {
      From = config.${namespace}.microvms.vmLan.cidr;
      To = oedoConfig.${namespace}.microvms.vmLan.cidr;
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

  # Add /etc/hosts entries for VMs we have access to on oedo
  networking.hosts =
    oedoConfig.microvm.vms
    |> lib.attrNames
    |> lib.map (name: {
      "${oedoConfig.microvm.vms.${name}.specialArgs.vmSpecs.ip}" = [ name ];
    })
    |> lib.mergeAttrsList;
}
