{
  lib,
  config,
  pkgs,
  ...
}:

let
  inherit (lib) mkIf mkOption types;
  cfg = config.services.swww;
in
{
  options.services.swww = {
    interval = mkOption {
      type = types.int;
      default = (60 * 60); # Hourly
      description = "Interval value for cycling between images";
    };

    transitionFPS = mkOption {
      type = types.int;
      default = 30;
      description = "Transition frames per second for the swww daemon";
    };

    transitionStep = mkOption {
      type = types.int;
      default = 5;
      description = "Transition step value for the swww daemon";
    };

    wallpaperDir = mkOption {
      type = types.str;
      default = "";
      description = "Path to the directory of wallpaper images";
    };
  };

  config = mkIf cfg.enable {
    # Prefer swww, and avoid hyprpaper crash loop
    services.hyprpaper.enable = lib.mkForce false;
    stylix.targets.hyprpaper.enable = lib.mkForce false;

    # Optionally, cycle through images in the wallpaper directory
    systemd.user.services.swww-cycle = mkIf (cfg.wallpaperDir != "") {
      Unit = {
        Description = "Cycle wallpaper images using swww";
        After = [ "swww.service" ];
        PartOf = [ "swww.service" ];
      };

      Service = {
        ExecStart = pkgs.writeShellScript "swww-cycle" ''
          #!/bin/bash
          while true; do
            images=($(ls -d ${cfg.wallpaperDir}/* | shuf))
            for img in "''${images[@]}"; do
              ${pkgs.swww}/bin/swww img \
                --transition-fps ${toString cfg.transitionFPS} \
                --transition-step ${toString cfg.transitionStep} \
                "$img"
              sleep ${toString cfg.interval}
            done
          done
        '';
        Restart = "always";
        RestartSec = 5;
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
