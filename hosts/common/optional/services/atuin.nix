{ lib, config, ... }:
{
  imports = [ ./nginx.nix ];
  config =
    let
      atuinPort = config.hostSpec.networking.ports.tcp.atuin;

      # NOTE: This slightly odd way of using both was to avoid infinite recursion. Also having both is
      # currently due to granularFirewall not supporting darwin and nftables yet
      cfg = config.networking.granularFirewall;
      granularFirewallRules = lib.mkIf cfg.enable {
        networking.granularFirewall.allowedRules = [
          {
            serviceName = "atuin";
            protocol = "tcp";
            ports = [ atuinPort ];
            hosts = config.hostSpec.networking.rules.${config.hostSpec.hostName}.atuinAllowedHosts;
          }
        ];
      };
      regularFirewallRules = lib.mkIf (cfg.enable == false) {
        networking.firewall.allowedTCPPorts = [ atuinPort ];
      };
    in
    lib.mkMerge [
      {
        services.atuin = {
          enable = true;
          port = atuinPort;
          openRegistration = true;
          maxHistoryLength = 1000000; # 1 million entries to start
        };

        services.nginxProxy.services = [
          {
            subDomain = "atuin";
            port = atuinPort;
            ssl = false;
          }
        ];

        # This is only for atuin atm, so need localhost only
        # FIXME: This should be separate with an import maybe. atticd will use this too...
        services.postgresql = {
          enable = true;
        };

        # FIXME: This should be switched to a function
        environment = lib.optionalAttrs config.system.impermanence.enable {
          persistence = {
            "${config.hostSpec.persistFolder}".directories = [ "/var/lib/postgresql" ];
          };
        };

        # Enable something to backup atuin/postgresql. See mic92 postgresqlBackup
      }
      granularFirewallRules
      regularFirewallRules
    ];
}
