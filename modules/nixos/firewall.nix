# As NixOS doesn't provide a way to do more granular firewall rules, this provides a way to do so.
# Any time you enable a service, rather than specifying the port is allowed, instead you specify the port and a list of
# IPs you want to accept connections from
{ config, lib, ... }:
# FIXME: This shouldn't be iptables specific eventually

let
  cfg = config.networking.granularFirewall;
  types = lib.types;
  # FIXME(firewall): Should we specify the interfaces?
  portConfigType = types.submodule {
    options = {
      protocol = lib.mkOption {
        type = types.enum [
          "tcp"
          "udp"
        ];
        default = "tcp";
        description = "Protocol to restrict";
      };
      ports = lib.mkOption {
        type = types.listOf types.port;
        description = "Port numbers to restrict to specified hosts only";
      };
      # FIXME: Make this a subtype for IP, name, mac, etc
      hosts = lib.mkOption {
        type = types.listOf types.anything;
        default = [ ];
        description = "List of IP addresses or subnets allowed to access this port";
      };
      serviceName = lib.mkOption {
        type = types.str;
        default = "Unknown";
        description = "Name of the service to restrict";
      };
    };
  };

  generateIptablesRules =
    rule:
    let
      allowRules = lib.concatMapStringsSep "\n" (
        port:
        lib.concatMapStringsSep "\n" (host: ''
          iptables -A nixos-fw \
            -p ${rule.protocol} \
            --dport ${toString port} \
            -s ${host.ip} \
            -j ACCEPT \
            -m comment --comment "Allow ${host.name} to ${rule.serviceName}"
        '') rule.hosts
      ) rule.ports;
      denyRules = lib.concatMapStringsSep "\n" (port: ''
        iptables -A nixos-fw -p ${rule.protocol} --dport ${toString port} -j DROP
      '') rule.ports;
    in
    allowRules + "\n" + denyRules;
in
{
  options.networking.granularFirewall = {
    enable = lib.mkEnableOption "Enable granular firewall rules";
    allowedRules = lib.mkOption {
      type = types.listOf portConfigType;
      default = [ ];
      description = "List of ports and IPs to allow connections from";
    };
  };
  config = lib.mkIf cfg.enable {
    networking.firewall.extraCommands = ''
      ${lib.concatStringsSep "\n" (map generateIptablesRules cfg.allowedRules)}
    '';
  };
}
