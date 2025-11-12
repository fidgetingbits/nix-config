{ config, ... }:
{
  services.blocky = {
    enable = true;

    settings = {
      # FIXME: Double check what we actually need
      connectIPVersion = "v4";

      log = {
        # level = "debug";
      };

      # Explicit IP to avoid conflict with systemd-resolve. Note explicit IP requires
      # the network to actually be up, so need network-online.target. See later.
      ports =
        let
          ip = config.hostSpec.networking.subnets.moon.hosts.moon.ip;
        in
        {
          dns = [ "${ip}:53" ];
          tls = [ "${ip}:853" ];
          https = [ "${ip}:443" ];
          #http = [ "${ip}:4000" ];
        };

      # FIXME(dns): Revisit
      # caching = {
      #   maxTime = "1h";
      #   prefetching = true;
      # };

      upstreams = {
        # strategy = "strict";
        # timeout = "30s";
        init.strategy = "fast";
        groups = {
          # FIXME: Need to fix this so it's an option
          default = config.hostSpec.networking.subnets.moon.dns.upstreams;
        };
      };

      blocking = {
        denylists = {
          default = [
            "https://hosts.oisd.nl"
            # Hagezi Pro - Comprehensive protection against ads, tracking, malware, phishing, scam, crypto-mining
            "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/hosts/pro.txt"
            # StevenBlack Unified Hosts - Consolidates multiple reputable sources
            "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
          ];
        };
      };
    };
  };

  systemd.services.blocky = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    startLimitIntervalSec = 1;
    startLimitBurst = 50;
  };

  networking.firewall = {
    allowedTCPPorts = [
      53
      443 # DoH
      853 # DoT
    ];
    allowedUDPPorts = [ 53 ];
  };
}
