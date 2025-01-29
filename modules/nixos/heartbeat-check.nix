# Run timers to check if other systems on the LAN are still alive
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.heartbeat-check;
  hearbeatScript = pkgs.writeScript "heartbeat.sh" ''
    #!/usr/bin/env bash
    set -euo pipefail
    STATE_DIR=/run/heartbeat
    mkdir -p $STATE_DIR || true

    function notify() {
      host=$1
      TMPDIR=$(mktemp -d)
      cat >"$TMPDIR"/heartbeat.txt <<-EOF
    From:box@${config.hostSpec.domain}
    Subject: [${config.networking.hostName}] $(date) $host Heartbeat Notice
      $2
    EOF
      ${lib.getBin pkgs.msmtp}/bin/msmtp -t admin@${config.hostSpec.domain} <"$TMPDIR"/heartbeat.txt
      rm -rf "$TMPDIR"
    }
    hosts=(${builtins.toString cfg.hosts})
    #echo "Checking hosts: ''${hosts[@]}"
      for host in ''${hosts[@]}; do
        if ! ${lib.getBin pkgs.inetutils}/bin/ping -c ${builtins.toString cfg.pingCount} -w 1 $host > /dev/null; then
          #echo "Host down: $host"
          if [ ! -f $STATE_DIR/$host ]; then
            echo "$(date)" > $STATE_DIR/$host
            notify $host "$host is not responding to pings from ${config.networking.hostName}"
          fi
        else
          #echo "Host up: $host"
          #echo $?
          if [ -f $STATE_DIR/$host ]; then
            notify $host "$host started responding to pings from ${config.networking.hostName}"
            rm -f $STATE_DIR/$host || true
          fi
        fi
      done
    #echo "Finished checking hosts"
  '';
in
{
  options.services.heartbeat-check = {
    enable = lib.mkEnableOption "Run timers to check if other systems on the LAN are still alive";
    interval = lib.mkOption {
      type = lib.types.int;
      default = 5 * 60;
      description = "Interval in seconds between heartbeat checks";
    };
    hosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of hosts to check for heartbeat";
    };
    pingCount = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "Number of pings to send to each host";
    };
  };
  config = lib.mkIf cfg.enable ({
    systemd = {
      services."heartbeat-check" = {
        description = "Check if other systems on the LAN are still alive";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.bash}/bin/bash ${hearbeatScript}";
          RemainAfterExit = false;
        };
      };
      timers."heartbeat-check" = {
        description = "Check if other systems on the LAN are still alive";
        wantedBy = [ "timers.target" ];
        after = [ "network-online.target" ];
        requires = [ "network-online.target" ];
        timerConfig = {
          Persistent = true;
          OnBootSec = "1min";
          OnUnitInactiveSec = "${builtins.toString cfg.interval}";
        };
      };
    };
  });
}
