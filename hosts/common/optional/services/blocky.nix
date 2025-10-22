{ config, ... }:
{
  services.blocky = {
    enable = true;

    settings = {
      # FIXME: Double check what we actually need
      connectIPVersion = "v4";
      startVerifyUpstream = false;

      log = {
        # level = "debug";
      };

      # Explicit IP to avoid conflict with systemd-resolve
      ports =
        let
          ip = config.hostSpec.networking.subnets.moon.hosts.moon.ip;
        in
        {
          dns = [ "${ip}:53" ];
          tls = [ "${ip}:853" ];
          https = [ "${ip}:443" ];
          http = [ "${ip}:4000" ];
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
          default = [
            # FIXME: Need to fix this so it's an option
            config.hostSpec.networking.subnets.moon.dns.upstreams
          ];
        };
      };

      blocking = {
        denylists = {
          default = [
            "https://hosts.oisd.nl"
          ];
        };
      };
    };
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
