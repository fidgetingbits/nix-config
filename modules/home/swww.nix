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
      description = "Transition frames per second";
    };

    transitionStep = mkOption {
      type = types.int;
      default = 5;
      description = "Transition step value";
    };

    transitionType = mkOption {
      type = types.str;
      default = "random";
      description = "Transition animation type";
    };

    wallpaperDir = mkOption {
      type = types.str;
      default = "";
      description = "Path to the directory of wallpaper images";
    };
  };

  config = mkIf cfg.enable {
    services.hyprpaper.enable = lib.mkForce false;
    stylix.targets.hyprpaper.enable = lib.mkForce false;

    # Skip current wallpaper with:
    # systemctl --user kill --signal SIGUSR1 swww-cycle.service
    systemd.user.services.swww-cycle = mkIf (cfg.wallpaperDir != "") {
      Unit = {
        Description = "Cycle wallpaper images using swww";
        After = [ "swww.service" ];
        PartOf = [ "swww.service" ];
      };

      Service = {
        Type = "simple";
        Restart = "always";
        RestartSec = 1;
        ExecStart =
          let
            shuf = lib.getExe' pkgs.coreutils "shuf";
            ls = lib.getExe' pkgs.coreutils "ls";
            sleep = lib.getExe' pkgs.coreutils "sleep";
          in
          pkgs.writeShellScript "swww-cycle" ''
            LAST_IMAGE=""
            function skip() {
              echo "Skipped $LAST_IMAGE"
              return
            }
            trap skip SIGUSR1

            function wait_swww() {
              echo "Checking swww daemon is up"
              while ! swww query 2>/dev/null; do
                # Handle: 'Error: "Socket file not found. Are you sure swww-daemon is running?"'
                sleep 1;
              done
              echo "swww daemon is accessible"
            }

            wait_swww

            while true; do
              images=($(${ls} -d ${cfg.wallpaperDir}/* | ${shuf}))
              for img in "''${images[@]}"; do
                ${pkgs.swww}/bin/swww img \
                  --transition-fps ${toString cfg.transitionFPS} \
                  --transition-step ${toString cfg.transitionStep} \
                  --transition-type ${cfg.transitionType} \
                  "$img"
                LAST_IMAGE="$img"
                if [ $? -ne 0 ]; then
                  echo "swww went down?"
                  wait_swww
                fi

                ${sleep} ${toString cfg.interval}
                wait $!
              done
            done
          '';
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
