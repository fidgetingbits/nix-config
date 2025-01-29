{
  pkgs,
  config,
  inputs,
  lib,
  ...
}:
let
  sopsFolder = (builtins.toString inputs.nix-secrets) + "/sops";
  workSecrets = "${sopsFolder}/work.yaml";
  vpnProfiles = inputs.nix-secrets.work.vpn.profiles;
in
{
  sops.secrets =
    {
      "vpn/client.crt" = {
        owner = config.users.users.${config.hostSpec.username}.name;
        inherit (config.users.users.${config.hostSpec.username}) group;
        sopsFile = "${workSecrets}";
      };
      "vpn/client.key" = {
        owner = config.users.users.${config.hostSpec.username}.name;
        inherit (config.users.users.${config.hostSpec.username}) group;
        sopsFile = "${workSecrets}";
      };
    }
    // lib.attrsets.mergeAttrsList (
      builtins.map (vpn: {
        # IMPORTANT: These must be root owned
        "vpn/${vpn}" = {
          path = "/etc/NetworkManager/system-connections/${vpn}.nmconnection";
          sopsFile = "${workSecrets}";
        };
      }) vpnProfiles
    );

  # FIXME: This should be a dispatcher script started when the VPN is connected...
  systemd.services.vpn-monitor = {
    description = "Monitor VPN connections";
    after = [
      "network.target"
      "NetworkManager.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash ${pkgs.writeScript "monitor-vpn.sh" ''
        #!/usr/bin/env bash
        ${pkgs.systemd}/bin/journalctl -u NetworkManager -f | \
        ${pkgs.gnugrep}/bin/grep --line-buffered "VPN connection .* disconnected" | \
        while read line; do
          ${pkgs.libnotify}/bin/notify-send "VPN Disconnected" "$line"
        done
      ''}";
      Restart = "always";
      RestartSec = "10s";
    };
  };

}
