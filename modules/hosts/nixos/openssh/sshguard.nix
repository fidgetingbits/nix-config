{ lib, config, ... }:
{
  services.sshguard =
    let
      minute = 60;
      hour = minute * 60;
    in
    {
      enable = true;
      blocktime = hour;
      detection_time = 8 * hour;
      blacklist_threshold = 30; # 3 strikes
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
