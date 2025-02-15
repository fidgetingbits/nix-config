{ config, lib, ... }:
let
  nginxPort = config.hostSpec.networking.ports.tcp.nginx;

  # NOTE: This slightly odd way of using both was to avoid infinite recursion. Also having both is
  # currently due to granularFirewall not supporting darwin and nftables yet
  cfg = config.networking.granularFirewall;
  granularFirewallRules = lib.mkIf cfg.enable {
    networking.granularFirewall.allowedRules = [
      {
        serviceName = "nginx";
        protocol = "tcp";
        ports = [ nginxPort ];
        hosts = config.hostSpec.networking.rules.${config.hostSpec.hostName}.nginxAllowedHosts;
      }
    ];
  };
  regularFirewallRules = lib.mkIf (cfg.enable == false) {
    networking.firewall.allowedTCPPorts = [ nginxPort ];
  };
in
lib.mkMerge [
  {
    services.nginx = {
      enable = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      recommendedTlsSettings = true;
    };

    # Grant nginx access to certificates
    # NOTE: Seems to barf if serviceConfig.User isn't set, but seems other people don't do this
    # so not entirely sure.
    #systemd.services.nginx.serviceConfig.User = config.services.nginx.user;
    #systemd.services.nginx.serviceConfig.SupplementaryGroup = [ "acme" ];

    # Reload nginx after certificate renewal
    security.acme.defaults.reloadServices = [ "nginx.service" ];

  }
  granularFirewallRules
  regularFirewallRules
]
