# Network UPS Tools (NUT) client
# FIXME: This is partially specific to myth atm
{
  lib,
  config,
  ...
}:
let

  upsmonNotifyTypes = {
    ONLINE = "UPS is back online";
    ONBATT = "UPS is on battery";
    LOWBATT = "UPS is on battery and has a low b{attery (is critical)";
    FSD = "UPS is being shutdown by the primary";
    COMMOK = "Communications established with the UPS";
    COMMBAD = "Communications lost to the UPS";
    SHUTDOWN = "The system is being shutdown";
    REPLBATT = "The UPS battery is bad and needs to be replaced";
    NOCOMM = "A UPS is unavailable (can't be contacted for monitoring)";
    NOPARENT = "upsmon parent process died - shutdown impossible";
    CAL = "UPS calibration in progress";
    NOTCAL = "UPS calibration finished";
    OFF = "UPS administratively OFF or asleep";
    NOTOFF = "UPS no longer administratively OFF or asleep";
    BYPASS = "UPS on bypass (powered, not protecting)";
    NOTBYPASS = "UPS no longer on bypass";
  };
in

{
  imports = [ ./upssched.nix ];
  power.ups = {
    enable = true;
    mode = "netclient";
    upsmon = {
      enable = true;
      monitor.ups =
        let
          # FIXME: The client info should be set or configured externally to this module
          server = config.hostSpec.networking.subnets.myth.hosts.synology.ip;
          port = toString config.hostSpec.networking.ports.tcp.nut;
        in
        {
          system = "ups@${server}:${port}";
          user = "monuser";
          passwordFile = config.sops.secrets."passwords/nut".path;
          type = "slave";
        };

      # Default upsmon settings use upssched command for NOTIFYCMD,
      # and waits on /run/killpower to die via. We use these upssched
      # rules to set timers and decide what to notify, when to die, etc
      # see upssched.nix for more
      settings = {
        NOTIFYMSG = lib.mapAttrsToList (k: v: [
          k
          v
        ]) upsmonNotifyTypes;

        # Define which UPS events log, call upssched, etc
        NOTIFYFLAG = [
          [
            "ONLINE"
            "SYSLOG+WALL+EXEC"
          ]
          [
            "ONBATT"
            "SYSLOG+WALL+EXEC"
          ]
          [
            "LOWBATT"
            "SYSLOG+WALL+EXEC"
          ]
          [
            "FSD"
            "SYSLOG+WALL+EXEC"
          ]
          [
            "COMMOK"
            "SYSLOG+WALL"
          ]
          [
            "COMMBAD"
            "SYSLOG+WALL+EXEC"
          ]
          [
            "SHUTDOWN"
            "SYSLOG+WALL+EXEC"
          ]
          [
            "REPLBATT"
            "SYSLOG+WALL+EXEC"
          ]
          [
            "NOCOMM"
            "SYSLOG+WALL+EXEC"
          ]
          [
            "NOPARENT"
            "SYSLOG+WALL+EXEC"
          ]
          [
            "CAL"
            "SYSLOG+WALL+EXEC"
          ]
          [
            "NOTCAL"
            "SYSLOG+WALL+EXEC"
          ]
          [
            "OFF"
            "SYSLOG+WALL+EXEC"
          ]
          [
            "NOTOFF"
            "SYSLOG+WALL+EXEC"
          ]
          [
            "BYPASS"
            "SYSLOG+WALL+EXEC"
          ]
          [
            "NOTBYPASS"
            "SYSLOG+WALL+EXEC"
          ]
        ];
      };
    };

  };

  mail-delivery.users = [
    config.hostSpec.primaryUsername
    config.power.ups.upsmon.user
  ];

  sops.secrets = {
    "passwords/nut" = {
      owner = config.power.ups.upsmon.user;
      group = config.power.ups.upsmon.group;
      mode = "0600";
    };
  };
}
