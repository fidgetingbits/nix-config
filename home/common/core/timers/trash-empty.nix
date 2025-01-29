{ pkgs, ... }:
{

  systemd.user.timers."trash-empty" = {
    Unit = {
      Description = "Weekly empty trash timer";
    };
    Install = {
      wantedBy = [ "timers.target" ];
    };
    Timer = {
      OnCalendar = "weekly";
    };
  };

  systemd.user.services."trash-empty" = {
    Unit = {
      Description = "Service to empty trash";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.trash-cli}/bin/trash-empty 30 -f";
    };
  };
}
