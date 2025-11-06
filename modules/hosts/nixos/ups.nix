# UPS module to handle both nut server and clients. Some helper options simplify
# the process. NUT is setup such that if you are the server, you typically are
# also your own client, so that client aspect is shared between systems who are
# servers or clients.
{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.services.ups;
  useUps = (cfg.client.enable || cfg.server.enable);

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

  upssched-notify = pkgs.writeShellApplication {
    name = "upssched-notify";
    runtimeInputs = [
      pkgs.msmtp
    ];
    text =
      # bash
      ''
        exec msmtp -t <<EOF
        To: ${config.hostSpec.email.admin}
        From: ${config.hostSpec.email.notifier}
        Subject: $HOSTNAME UPS status: $*

        $HOSTNAME UPS status: $*
        EOF
      '';
  };

  upssched-cmd = pkgs.writeShellApplication {
    name = "upssched-cmd";
    runtimeInputs = [
      pkgs.logger
      pkgs.nut
    ];
    text =
      # bash
      ''
        log_event () {
          logger -t upssched-cmd "$1"
        }
        # This script should be called by upssched via the CMDSCRIPT directive.
        # The first argument passed is the name of the timer from your AT lines or the value of EXECUTE directive
        case $1 in
          halt)
            log_event "Got the halt event"
            ${lib.getExe' upssched-notify "upssched-notify"} "$*"
            # Tell upsmon to trigger shutdown
            upsmon -c fsd
            ;;
          *)
            log_event "Unrecognized command: $*"
            ;;
        esac
      '';
  };
in
{
  options = {
    services.ups = {
      name = lib.mkOption {
        type = lib.types.str;
        example = "ups";
        description = "Name of the UPS device. Must match the name used by the NUT server";
      };
      username = lib.mkOption {
        type = lib.types.str;
        example = "nut";
        description = "Username for accessing the NUT server";
      };

      powerDownTimeOut = lib.mkOption {
        type = lib.types.int;
        default = 120; # 2 minutes
        example = 120;
        description = "The time in seconds to wait before shutting the system down on power failure";
      };

      port = lib.mkOption {
        type = lib.types.int;
        default = config.hostSpec.networking.ports.tcp.nut;
        example = config.hostSpec.networking.ports.tcp.nut;
        description = "Port of the NUT server";
      };

      ip = lib.mkOption {
        type = lib.types.str;
        default = "localhost";
        example = "192.168.1.100";
        description = "Address of the NUT server";
      };
      server = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          example = true;
          description = "Enables the NUT server and listen remotely on the network for NUT clients";
        };
      };

      client = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = config.services.ups.server.enable;
          example = true;
          description = "Enables the NUT client logic. Automatically set to true for NUT servers.";
        };
      };
    };
  };

  # imports = lib.optional useUps [ ./upssched.nix ];
  config = lib.mkIf (useUps) {
    # Shared NUT logic for server and client

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

    power.ups = {
      enable = true;
      mode = if cfg.server.enable then "netserver" else "netclient";

      # The client monitoring UPS events that will call upssched to trigger
      # timers and dispatch emails
      upsmon = {
        monitor.${cfg.name} = {
          system = "${cfg.name}@${cfg.ip}:${toString cfg.port}";
          user = cfg.username;
          passwordFile = config.sops.secrets."passwords/nut".path;
          type = if cfg.server.enable then "primary" else "slave";
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

          # Define which UPS events log and exec upssched
          # ATM all entries will call into upssched
          # FIXME: we could use an option or something to allow changes in a list and
          # filter those from the auto adding
          NOTIFYFLAG = lib.map (k: [
            k
            "SYSLOG+WALL+EXEC"
          ]) (lib.attrNames upsmonNotifyTypes);
        };
      };

      # upssched rules. Called by upsmon on an event
      # see https://networkupstools.org/docs/man/upssched.conf.html
      # These entries are parsed in sequence, so you can include multiple
      # rules or each event.
      schedulerRules =
        let
          systemGraceTime = toString cfg.powerDownTimeOut;
        in
        ''
          CMDSCRIPT ${lib.getExe upssched-cmd}

          PIPEFN /var/state/ups/upssched.pipe
          LOCKFN /var/state/ups/upssched.lock

          # Syntax:
          # AT <notifyType> <upsName> <command>
          # START-TIMER           <timername>     <interval>
          # CANCEL-TIMER          <timername>     [cmd]
          # EXECUTE               <command>


          # If on battery -- start death timer
          AT ONBATT    * START-TIMER halt ${systemGraceTime}
          AT ONLINE    * CANCEL-TIMER halt

          # Halt on low battery and or shutdown
          AT LOWBATT   * EXECUTE halt
          AT FSD       * EXECUTE halt

          # If communication to the server is lost -- start death timer
          # NOTE: This will trigger a timer even if the NUT client is temporarily
          # unable to contact the NUT server (or if the client is misconfigured)
          # so be careful about adding the timer until you are sure the system is
          # stable
          # AT COMMBAD   * START-TIMER halt ${systemGraceTime}
          # AT NOCOMM    * START-TIMER halt ${systemGraceTime}
          AT COMMBAD   * EXECUTE COMMBAD
          AT NOCOMM    * EXECUTE NOCOMM
          AT COMMOK    * CANCEL-TIMER halt
          AT COMMOK    * EXECUTE COMMOK


          # Log the following as unknown commands. Revisit these
          AT REPLBATT  * EXECUTE REPLBATT
          AT NOPARENT  * EXECUTE NOPARENT
          AT CAL       * EXECUTE CAL
          AT NOTCAL    * EXECUTE NOTCAL
          AT OFF       * EXECUTE OFF
          AT NOTOFF    * EXECUTE NOTOFF
          AT BYPASS    * EXECUTE BYPASS
          AT NOTBYPASS * EXECUTE NOTBYPASS
          AT SUSPEND_STARTING * EXECUTE SUSPEND_STARTING
          AT SUSPEND_FINISHED * EXECUTE SUSPEND_FINISHED
        ''
        |> (pkgs.writeText "upssched.conf")
        |> toString;
    }
    # NUT Server additions
    // lib.optionalAttrs cfg.server.enable {
      openFirewall = true;
      upsd = {
        listen = [
          {
            address = "0.0.0.0";
            port = config.hostSpec.networking.ports.tcp.nut;
          }
        ];
      };

      # These are the users that can auth to the nut server
      users.${cfg.username} = {
        passwordFile = config.sops.secrets."passwords/nut".path;
        upsmon = "primary";
      };

    };
    # Make sure that power.ups.ups.<device> was defined for the server
    assertions = (
      lib.optional cfg.server.enable {
        assertion = (lib.length (lib.attrNames config.power.ups.ups) != 0);
        message = "NUT servers must specify config.power.ups.ups.<device> to define your UPS device";
      }
    );
  };
}
