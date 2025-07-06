{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:
let
  attic = pkgs.attic-client;
  attic_token = config.sops.secrets."tokens/attic-client".path;
  attic_server = "https://atticd.ooze.${config.hostSpec.domain}";
  sopsFolder = (builtins.toString inputs.nix-secrets) + "/sops";
in
{
  options = {
    attic-client = {
      cache-name = lib.mkOption {
        type = lib.types.str;
        default = "o-cache";
        description = "The name of the attic cache";
      };
    };
  };

  config = lib.mkIf config.hostSpec.useAtticCache {
    nix.settings = {
      extra-substituters = [ "${attic_server}//${config.attic-client.cache-name}" ];
      extra-trusted-public-keys = [
        # Following key comes from: attic cache info <cache>
        "o-cache:GRHaMHaWAzG3B6oTridUh8hA1GeCPuAlkRFAmICR7sw="
      ];
    };

    sops.secrets."tokens/attic-client" = {
      sopsFile = "${sopsFolder}/shared.yaml";
    };

    systemd.services.attic-token-check = {
      description = "Check attic token expiration";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "check-attic-token" ''
          #!/bin/bash
          set -euo pipefail

          ATTIC_TOKEN=$(cat ${attic_token})

          # Decode JWT payload
          PAYLOAD=$(echo "$ATTIC_TOKEN" | cut -d. -f2 | base64 -d)
          EXP=$(echo "$PAYLOAD" | ${pkgs.jq}/bin/jq -r '.exp')

          # Calculate days until expiry
          NOW=$(date +%s)
          DAYS_LEFT=$(( (EXP - NOW) / 86400 ))

          if [ "$DAYS_LEFT" -lt 30 ]; then
            echo "WARNING: Attic token expires in $DAYS_LEFT days"
            # Send email if configured
            if command -v mail >/dev/null; then
                    TMPDIR=$(mktemp -d)
            cat >"$TMPDIR"/expiry.txt <<-EOF
          From:box@${config.hostSpec.domain}
          Subject: [${config.networking.hostName}] $(date) Attic Token Expiry Notice
          The attic token for ${config.attic-client.cache-name} is expiring soon.
            $2
          EOF
              ${lib.getBin pkgs.msmtp}/bin/msmtp -t admin@${config.hostSpec.domain} <"$TMPDIR"/expiry.txt
              rm -rf "$TMPDIR"
            fi
            exit 1
          else
            echo "Attic token valid for $DAYS_LEFT more days"
          fi
        '';
      };
    };
    systemd.timers.attic-token-check = {
      description = "Check attic token expiration daily";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

    systemd.services.attic-watch-store = {
      description = "Attic client watch-store service";
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.writeShellScript "watch-store" ''
          #!/run/current-system/sw/bin/bash
          set -x
          ATTIC_TOKEN=$(cat ${attic_token})
          ${attic}/bin/attic login ${config.attic-client.cache-name} ${attic_server} $ATTIC_TOKEN
          ${attic}/bin/attic watch-store ${config.attic-client.cache-name}
        ''}";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    services.per-network-services.trustedNetworkServices = [ "attic-watch-store" ];

  };
}
