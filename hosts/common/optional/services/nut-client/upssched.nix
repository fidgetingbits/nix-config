{
  pkgs,
  lib,
  config,
  ...
}:
let

  # FIXME: This should be an option
  systemGraceTime = "120";

  upssched-notify = pkgs.writeShellApplication {
    name = "upssched-notify";
    runtimeInputs = [
      pkgs.mailutils
    ];
    text =
      # bash
      ''
        MAILTO="${config.hostSpec.email.admin}"

        exec mail -t <<EOF
        To: $MAILTO
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
            upssched-notify "$*"
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

  # see https://networkupstools.org/docs/man/upssched.conf.html
  power.ups.schedulerRules =
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
      AT COMMBAD   * START-TIMER halt ${systemGraceTime}
      AT NOCOMM    * START-TIMER halt ${systemGraceTime}
      AT COMMOK    * CANCEL-TIMER halt comm_ok_action
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
