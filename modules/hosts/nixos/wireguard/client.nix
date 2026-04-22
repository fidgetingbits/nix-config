# See https://github.com/JManch/nixos/blob/a34ee3/modules/nixos/services/wireguard.nix#L263
# for some more ideas
{
  config,
  namespace,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.${namespace}.wireguard;

  mkWireguardPeer = role: host: {
    publicKey = host.wgpk;
    allowedIPs = cfg.allowedIPs;
    endpoint = "${cfg.endpoint}:${toString cfg.wireguardPort}";
    # Needed on clients for keeping NAT open
    persistentKeepalive = 25;
  };
  mkWireguardPeers = role: hosts: (map (host: mkWireguardPeer role host) hosts);
in
lib.mkIf (cfg.enable && cfg.role == "client") {
  # See ./default.nix for shared settings across client/server

  # NOTE: Setting this to unmanaged breaks networking.wireguard as is, maybe only works if you use systemd.networkd
  # networking.networkmanager.unmanaged = [ "interface-name:${cfg.interface}" ];
  # Prevent networkmanager messing with resovlectl settings, etc.
  networking.dhcpcd.denyInterfaces = [ cfg.interface ];

  networking = {
    wireguard = {
      interfaces =
        let
          resolvectl = lib.getExe' pkgs.systemd "resolvectl";
        in
        {
          # FIXME: This should loop over multiple interfaces, since eventually clients will have multiples
          ${cfg.interface} = {
            # FIXME: This could be set if we indicate endpoint is a dns?
            # Force endpoint updates in case IP changes (required for wireguard server endpoint behind dyndns)
            dynamicEndpointRefreshSeconds = 5;

            allowedIPsAsRoutes = false; # FIXME: Probably want this dependent on how the VPN is setup, this lets me adjust metrics for my LAN
            peers =
              cfg.peerNames
              |> map (name: cfg.hosts.${name})
              # nixfmt hack
              |> mkWireguardPeers cfg.role;

            # Manually manage routes so we can adjust the metric. This allows staying
            # connected to wireguard while on the LAN, but favoring routing locally. Metric just
            # has to be higher than what we set for LAN (50)
            preSetup = "set -x";
            # FIXME: Make this writeShellApplication for cleaner tool use
            postSetup = # bash
              ''
                ${lib.concatMapStringsSep "\n" (
                  ip: "ip route replace ${ip} dev ${cfg.interface} metric 200"
                ) cfg.allowedIPs}

                 ${lib.optionalString cfg.dns.enable ''
                    # FIXME: This will lneed to change for full tunnel
                    ${resolvectl} default-route ${cfg.interface} false
                    ${resolvectl} domain ${cfg.interface} ${
                      lib.concatMapStringsSep " " (domain: "\"~${domain}\"") ([ cfg.dns.domain ])
                    }
                    ${resolvectl} dns ${cfg.interface} ${cfg.dns.server}

                   # FIXME: This might be a bit error prone if the defualt route isn't what you want to resolve it with?
                   # IMPORTANT: Don't resolve the endpoint using the internal DNS. If dynamicEndpointRefreshSeconds is set,
                   # this will bust the connection
                   EIFACE=$(ip route show default | ${lib.getExe pkgs.gawk} '/default/ {print $5}' | head -n1)
                   ${resolvectl} domain "$EIFACE" "~${cfg.endpoint}"
                 ''}
              '';
            preShutdown = # bash
              ''
                echo "preShutdown"
                # ${lib.concatMapStrings (ip: "ip route del ${ip} dev ${cfg.interface} metric 200") cfg.allowedIPs}
                ip route del ${cfg.subnet} dev ${cfg.interface} metric 200
              '';
          };
        };
    };
  };
}
