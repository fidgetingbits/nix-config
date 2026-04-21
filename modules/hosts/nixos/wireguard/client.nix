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
    endpoint =
      # FIXME: Maybe need a cfg.endpoint instead, in case client doesn't want to use domain?
      "${host.name}.${config.hostSpec.domain}:${toString cfg.networkParams.wireguardPort}";
    # Needed on clients for keeping NAT open
    persistentKeepalive = 25;
  };
  mkWireguardPeers = role: hosts: (map (host: mkWireguardPeer role host) hosts);
in
lib.mkIf (cfg.enable && cfg.role == "client") {
  # See ./default.nix for shared settings across client/server
  networking = {
    wireguard = {
      interfaces =
        let
          resolvectl = lib.getExe' pkgs.systemd "resolvectl";
        in
        {
          ${cfg.interface} = {
            # Force endpoint updates in case IP changes (required for wireguard server using dyndns, etc)
            dynamicEndpointRefreshSeconds = 5;
            peers =
              cfg.peerNames
              |> map (name: cfg.hosts.${name})
              # nixfmt hack
              |> mkWireguardPeers cfg.role;

            # Manually manage routes so we can adjust the metric. This allows staying
            # connected to wireguard while on the LAN, but favoring routing locally. Metric just
            # has to be higher than what we set for LAN (50)
            # NOTE: This currently routes everything. May need to match AllowedIPs entries or something?
            postSetup = # bash
              ''
                ${lib.concatMapStringsSep "\n" (
                  ip: "ip route add ${ip} dev ${cfg.interface} metric 200"
                ) cfg.allowedIPs}

                ${
                  # FIXME: Maybe just use an enable, like the link above
                  if (cfg.networkParams ? "domain") then
                    ''
                      ${resolvectl} default-route ${cfg.interface} false
                      ${resolvectl} domain ${cfg.interface} ${
                        # FIXME: Make this an option probably
                        lib.concatMapStringsSep " " (domain: "\"~${domain}\"") ([ cfg.networkParams.domain ])
                      }
                    ''
                  else
                    ""
                }
              '';
            postShutdown = # bash
              ''
                ${lib.concatMapStrings (ip: "ip route del ${ip} dev ${cfg.interface} metric 200") cfg.allowedIPs}
                ip route del ${cfg.networkParams.subnet} dev ${cfg.interface} metric 200
              '';
          };
        };
    };
  };
  programs.zsh.shellAliases = {
    "${cfg.interface}-up" = "sudo systemctl start wg-quick-${cfg.interface}";
    "${cfg.interface}-down" = "sudo systemctl stop wg-quick-${cfg.interface}";
  };
}
