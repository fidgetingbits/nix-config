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

  # Maybe change this name since lib.custom.network has it
  mkWireguardPeer = role: host: {
    inherit (host) name;
    publicKey = host.wireguardPubKey;
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
            peers = mkWireguardPeers cfg.role cfg.peers;

            # Manually manage routes so we can adjust the metric. This allows staying
            # connected to wireguard while on the LAN, but favoring routing locally. Metric just
            # has to be higher than what we set for LAN (50)
            preSetup = "set -x";
            # FIXME: Make this writeShellApplication for cleaner tool use
            postSetup =
              # bash
              ''
                ${lib.concatMapStringsSep "\n" (
                  ip: "ip route replace ${ip} dev ${cfg.interface} metric 200"
                ) cfg.allowedIPs}

                ${lib.optionalString cfg.dns.enable ''
                   # FIXME: This will need to change for full tunnel
                   ${resolvectl} default-route ${cfg.interface} false
                   ${resolvectl} domain ${cfg.interface} ${
                     lib.concatMapStringsSep " " (domain: "\"~${domain}\"") ([ cfg.dns.domain ])
                   }
                   ${resolvectl} dns ${cfg.interface} ${cfg.dns.server}

                  # FIXME: This might be a bit error prone if the defualt route isn't what you want to resolve it with?
                  # IMPORTANT: Don't resolve the endpoint using the internal DNS. If dynamicEndpointRefreshSeconds is set,
                  # this will bust the connection
                  until ip route show default | grep -q default; do
                    sleep 1
                  done
                  EIFACE=$(ip route show default | ${lib.getExe pkgs.gawk} '/default/ {print $5}' | head -n1)
                  ${resolvectl} domain "$EIFACE" "~${cfg.endpoint}"
                ''}
              '';
            preShutdown = # bash
              ''
                echo "preShutdown"
                # ${lib.concatMapStrings (ip: "ip route del ${ip} dev ${cfg.interface} metric 200") cfg.allowedIPs}
                ip route del ${cfg.subnet.cidr} dev ${cfg.interface} metric 200
              '';
          };
        };
    };
  };

  # FIXME: tweak threshold, only enable with option, specify peer for handshakes
  # Watchdog: restart the tunnel if the WireGuard handshake goes stale.
  # When the wireguard server doesn't have a static IP, and it changes,
  # the client won't periodically check the updated DNS entry on it's
  # own. If the last handshake is older than 4 min the peer is unreachable.
  systemd.services."wireguard-${cfg.interface}-watchdog" = {
    description = "WireGuard tunnel health check";
    serviceConfig.Type = "oneshot";
    script = # bash
      ''
        # FIXME: Change this to a multiplier of the configured keepalive
        STALE_THRESHOLD=240 # 4min

        if ! systemctl is-active --quiet wireguard-${cfg.interface}.service; then
          echo "Wireguard service not active, restarting..."
          systemctl restart wireguard-${cfg.interface}.service
          exit 0
        fi

        HANDSHAKE=$(${pkgs.wireguard-tools}/bin/wg show wg0 latest-handshakes 2>/dev/null \
          | ${pkgs.gawk}/bin/awk '{print $2}' | sort -n | tail -1)

        if [ -z "$HANDSHAKE" ] || [ "$HANDSHAKE" = "0" ]; then
          echo "No handshake recorded yet, restarting..."
          systemctl restart wireguard-${cfg.interface}.service
          exit 0
        fi

        NOW=$(date +%s)
        AGE=$((NOW - HANDSHAKE))

        if [ "$AGE" -gt "$STALE_THRESHOLD" ]; then
          echo "Handshake is ''${AGE}s old (threshold: ''${STALE_THRESHOLD}s), restarting..."
          systemctl restart wireguard-${cfg.interface}.service
        else
          echo "Handshake is ''${AGE}s old, tunnel OK"
        fi
      '';
  };

  systemd.timers."wireguard-${cfg.interface}-watchdog" = {
    description = "Periodic WireGuard health check";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "1min";
    };
  };
}
