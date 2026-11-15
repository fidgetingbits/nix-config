{
  lib,
  config,
  namespace,
  ...
}:
{
  config =
    let
      atuinPort = config.hostSpec.networking.ports.tcp.atuin;

      # NOTE: This slightly odd way of using both was to avoid infinite recursion. Also having both is
      # currently due to granularFirewall not supporting darwin and nftables yet
      cfg = config.${namespace}.networking.granularFirewall;
      granularFirewallRules = lib.mkIf cfg.enable {
        ${namespace}.networking.granularFirewall.allowedRules = {
          atuin = {
            serviceName = "atuin";
            protocol = "tcp";
            ports = [ atuinPort ];
            hosts = config.hostSpec.networking.rules.${config.hostSpec.hostName}.atuinAllowedHosts;
          };
        };
      };
      regularFirewallRules = lib.mkIf (cfg.enable == false) {
        networking.firewall.allowedTCPPorts = [ atuinPort ];
      };
    in
    lib.mkMerge [
      {
        ${namespace} = {
          services.nginx.enable = true;
          services.nginxProxy.services = [
            {
              subDomain = "atuin";
              port = atuinPort;
              ssl = false;
            }
          ];
        };
        services.atuin = {
          enable = true;
          port = atuinPort;
          openRegistration = true;
          maxHistoryLength = 1000000; # 1 million entries to start
        };

      }
      granularFirewallRules
      regularFirewallRules
    ];
}
