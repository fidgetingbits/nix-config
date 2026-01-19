{
  config,
  pkgs,
  inputs,
  lib,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.attic-client;
in
{
  options.${namespace}.attic-client = {
    enable = lib.mkEnableOption "Enable attic cache client logic";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.attic-client;
      description = "attic-client to use";
    };
    server = lib.mkOption {
      type = lib.types.str;
      default = "https://atticd.ooze.${config.hostSpec.domain}";
      description = "attic cache URL";
    };

    pubKey = lib.mkOption {
      type = lib.types.str;
      default = "o-cache:InDTfgsYEL5xDqYMa/KFtBK3AM/z0XbBAIgPr44qmdY=";
      description = "attic cache's public key found via attic cache info <cache>";
    };

    tokenPath = lib.mkOption {
      type = lib.types.path;
      default = config.sops.secrets."tokens/attic-client".path;
      description = "attic access token path";
    };

    cache-name = lib.mkOption {
      type = lib.types.str;
      default = "o-cache";
      description = "Name of the attic cache";
    };

    sopsFile = lib.mkOption {
      type = lib.types.path;
      default = (builtins.toString inputs.nix-secrets) + "/sops/olan.yaml";
      description = "sops file containing attic cache access token";
    };

    # FIXME: This may be some sort of custom type candidate, since we use it all over
    notify = lib.mkOption {
      type = lib.types.submodule {
        options = {
          to = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ config.hostSpec.email.admin ];
            example = [ "admin@example.com" ];
            description = "List of emails to send notifications from";
          };
          from = lib.mkOption {
            type = lib.types.str;
            default = config.hostSpec.email.notifier;
            example = "notifications@example.com";
            description = "Email address to send UPS notifications to";
          };
        };
      };
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    nix.settings = {
      extra-substituters = [ "${cfg.server}/${cfg.cache-name}" ];
      extra-trusted-public-keys = [
        cfg.pubKey
      ];
    };

    sops.secrets."tokens/attic-client".sopsFile = cfg.sopsFile;

    systemd.services.attic-token-check =
      let
        # FIXME: We should just use a builder function for this, since we use it often
        token-expiry-notify = pkgs.writeShellApplication {
          name = "token-expiry-notify";
          runtimeInputs = [
            pkgs.msmtp
          ];
          text =
            let
              recipients = lib.concatStringsSep ", " cfg.notify.to;
            in
            # bash
            ''
              exec msmtp -t <<EOF
              To: ${recipients}
              From: ${cfg.notify.from}
              Subject: [${config.networking.hostName}: attic] Attic Token Expiry Notice
              The attic token for ${cfg.cache-name} is expiring soon.
                $2
              EOF
            '';
        };

        check-attic-token = pkgs.writeShellApplication {
          name = "check-attic-token";
          runtimeInputs = lib.attrValues {
            inherit (pkgs)
              coreutils
              jq
              msmtp
              ;
          };
          text =
            # bash
            ''
              set -euo pipefail

              ATTIC_TOKEN=$(cat ${cfg.tokenPath})

              # Decode JWT payload
              PAYLOAD=$(echo "$ATTIC_TOKEN" | cut -d. -f2 | base64 -d)
              EXP=$(echo "$PAYLOAD" | jq -r '.exp')

              # Calculate days until expiry
              NOW=$(date +%s)
              DAYS_LEFT=$(( (EXP - NOW) / 86400 ))

              if [ "$DAYS_LEFT" -lt 30 ]; then
                echo "WARNING: Attic token expires in $DAYS_LEFT days"
                ${lib.getExe' token-expiry-notify "token-expiry-notify"}
              else
                echo "Attic token valid for $DAYS_LEFT more days"
              fi
            '';
        };
      in
      {
        description = "Check attic token expiration";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe' check-attic-token "check-attic-token";
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

    systemd.services.attic-watch-store =
      let
        attic-watch-store = pkgs.writeShellApplication {
          name = "attic-watch-store";
          runtimeInputs = [
            cfg.package
          ];
          text =
            # bash
            ''
              ATTIC_TOKEN=$(cat ${cfg.tokenPath})
              # FIXME: Add a check that the expected cache exists first and
              # exit/create if not?
              attic login ${cfg.cache-name} ${cfg.server} "$ATTIC_TOKEN"
              attic watch-store ${cfg.cache-name}
            '';
        };
      in
      {
        description = "Attic client watch-store service";
        after = [ "network.target" ];
        wantedBy = [ "default.target" ];
        serviceConfig = {
          ExecStart = lib.getExe' attic-watch-store "attic-watch-store";
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };

    ${namespace}.services.per-network-services.trustedNetworkServices = [ "attic-watch-store" ];

    # Client is added system-wide for manual debugging. Keeps the version the same as the
    # option (vs using a shell.nix version)
    environment.systemPackages = [
      cfg.package
    ];

  };
}
