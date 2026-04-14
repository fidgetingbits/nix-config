# As NixOS doesn't provide a way to do more granular firewall rules, this provides a way to do so.
# Any time you enable a service, rather than specifying the port is allowed, instead you specify the port and a list of
# IPs you want to accept connections from
{ config, lib, ... }:

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
    networking.firewall.extraInputRules = lib.concatMapStringsSep "\n" (
      rule:
      let
        ipList = "{ ${lib.concatStringsSep ", " (map (h: h.ip) rule.hosts)} }";
        portList = "{ ${lib.concatStringsSep ", " (map toString rule.ports)} }";
      in
      ''
        ip saddr ${ipList} ${rule.protocol} dport ${portList} accept comment "Allow ${rule.serviceName}"
        ${rule.protocol} dport ${portList} drop comment "Deny others to ${rule.serviceName}"
      ''
    ) cfg.allowedRules;
  };
}
