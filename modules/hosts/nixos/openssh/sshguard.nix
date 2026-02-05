{ lib, config, ... }:
{
  services.sshguard =
    let
      time = lib.custom.time;
    in
    {
      enable = true;
      blocktime = (time.hours 1);
      detection_time = (time.days 2);
      blacklist_threshold = 30; # 3 strikes
    };
  systemd.services.sshguard.serviceConfig = {
    TimeoutStopSec = "2s"; # Default is 1m30s and holds up restart
    KillMode = "mixed";
  };

  environment =
    lib.optionalAttrs (config.system ? impermanence && config.system.impermanence.enable)
      {
        persistence = {
          "${config.hostSpec.persistFolder}".directories = [
            {
              # NOTE: systemd Dynamic User requires /var/lib/private to be 0700. See impermanence module
              directory = "/var/lib/sshguard";
              #user = "nobody";
              #group = "nogroup";
            }
          ];
        };
      };

}
