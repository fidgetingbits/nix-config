{ config, namespace, ... }:
let
  # FIXME: This should be configurable?
  vm-lan = config.hostSpec.networking.subnets.nlan;
  vmBridge = "vbr-microvms";
  vpnCfg = config.${namespace}.microvms.vpn;
in
{
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  systemd.network = {
    enable = true;
    wait-online.enable = false;

    # Bridge device for microvms back to host
    netdevs."20-${vmBridge}".netdevConfig = {
      Kind = "bridge";
      Name = vmBridge;
    };

    networks."20-${vmBridge}" = {
      matchConfig.Name = vmBridge;
      addresses = [ { Address = "${vm-lan.gateway}/${toString vm-lan.prefixLength}"; } ];
      networkConfig.ConfigureWithoutCarrier = true;

      routingPolicyRules = [
        # Allow access between the guest and the host
        {
          From = vm-lan.cidr;
          To = vm-lan.cidr;
          Table = "main";
          Priority = 999;
        }
        # Route everything else over VPN
        {
          From = vm-lan.cidr;
          Table = vpnCfg.tableNum;
          Priority = 1000;
        }
      ];
    };

    # Creates a tap between vbr-agents and all agent vms that follow the vm-*
    # naming pattern
    networks."21-${vmBridge}-tap" = {
      matchConfig.Name = "vm-microvm-*"; # NOTE: Corresponds to mkMicrovm func's microvms.interfaces
      networkConfig.Bridge = vmBridge;
    };
  };

  # Outbound NAT only for packets going out the proton vpn
  # Allow established traffic for host -> microvm ssh session
  networking.nftables = {
    enable = true;
    ruleset = ''
      table inet vm_firewall {
            chain input {
              type filter hook input priority filter; policy accept;

              ct state established,related accept
              iifname "${vmBridge}" drop
            }

            chain output {
             type filter hook output priority filter;
             oifname "${vmBridge}" accept
            }

            chain forward {
              type filter hook forward priority filter; policy drop;

              # Allow established internet traffic back to the VM
              ct state established,related accept

              # Allow the VM to route outbound traffic to the VPN interface
              iifname "${vmBridge}" oifname "${vpnCfg.ifname}" accept
            }

            chain postrouting {
              type nat hook postrouting priority filter; policy accept;
              oifname "${vpnCfg.ifname}" masquerade
            }
          }
    '';
  };
}
