# Network UPS Tools (NUT) server
{
  lib,
  config,
  ...
}:
let

  upsmonNotifyTypes = {
    ONLINE = "UPS is back online";
    ONBATT = "UPS is on battery";
    LOWBATT = "UPS is on battery and has a low battery (is critical)";
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
  systemd.tmpfiles.rules = [
    "d /var/state/ups 0755 nutmon nutmon -"
  ];

  systemd.services.upsmon = {
    serviceConfig = {
      # Gets rid of the warning:
      # `upsnotify: notify about state 2 with libsystemd: was requested, but ...`
      # Note however that the above warning isn't actually important afaict and doesn't
      # adversely affect the functionality of the upsmon service.
      NotifyAccess = "all";
      # The IPC in upssched defines these, but nutmon user doesn't have access
      ReadWritePaths = "/var/state/ups";
    };
    environment = {
      # Useful to check if you are actually talking to the server, if no upssched
      # output yet
      #NUT_DEBUG_LEVEL = "10";
    };
  };
  power.ups = {
    enable = true;
    mode = "netserver";
    # FIXME: add a list of trusted hosts that can connect on grove LAN
    # currently restricted by guard rules
    openFirewall = true;
    upsd = {
      listen = [
        {
          address = "0.0.0.0";
          port = config.hostSpec.networking.ports.tcp.nut;
        }
      ];
    };

    ups.cyberpower = {
      driver = "usbhid-ups";
      description = "CyberPower CP1500PFCLCDa";
      port = "auto";
      directives = [
        "vendorid = 0764"
        "productid = 0601"
      ];
    };

    # These are the users that can auth to the nut server
    users.nut = {
      passwordFile = config.sops.secrets."passwords/nut".path;
      upsmon = "primary";
    };

    upsmon = {
      #enable = true;
      #monitor."CP1500PFCLCDa" =
      monitor."cyberpower" = {
        system = "cyberpower@localhost";
        user = "nut";
        passwordFile = config.sops.secrets."passwords/nut".path;
        type = "primary";
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
            "SYSLOG+WALL+EXEC"
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
