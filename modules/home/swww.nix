# Originally from https://github.com/JenSeReal/NixOS/blob/main/packages/swww/default.nix
{
  lib,
  config,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.swww2;
in
{
  options.services.swww2 = {
    enable = mkEnableOption "Enable the swww wallpaper manager";

    interval = mkOption {
      type = types.int;
      default = 10;
      description = "Interval value for the swww daemon";
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
    home.packages = [ pkgs.swww ];

    systemd.user.services.swww = {
      Unit = {
        Description = "swww daemon";
        After = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = [
          "${pkgs.swww}/bin/swww"
          "daemon"
          "--interval"
          (toString cfg.interval)
          "--transition-fps"
          (toString cfg.transitionFPS)
          "--transition-step"
          (toString cfg.transitionStep)
        ];
        Restart = "always";
        RestartSec = 5;
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    # Optionally, cycle through images in the wallpaper directory
    systemd.user.services.swww-cycle = mkIf (cfg.wallpaperDir != "") {
      Unit = {
        Description = "Cycle wallpaper images using swww";
        After = [ "swww.service" ];
        PartOf = [ "swww.service" ];
      };

      Service = {
        ExecStart = [
          "${pkgs.bash}/bin/bash"
          "-c"
          ''
            while true; do
              for img in ${cfg.wallpaperDir}/*; do
                ${pkgs.swww}/bin/swww img "$img"
                sleep ${toString cfg.interval}
              done
            done
          ''
        ];
        Restart = "always";
        RestartSec = 5;
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
