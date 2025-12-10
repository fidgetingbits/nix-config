{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkOption types;
  cfg = config.services.awww;
in
{
  options.services.awww = {
    enable = lib.mkEnableOption "Enable awww services";
    interval = mkOption {
      type = types.int;
      default = (60 * 60); # Hourly
      description = "Interval value for cycling between images";
    };

    cyclePerMonitor = mkOption {
      type = lib.types.bool;
      default = true;
      description = "Set a different image per monitor";
    };

    transitionFPS = mkOption {
      type = types.int;
      default = 144;
      description = "Transition frames per second";
    };

    transitionStep = mkOption {
      type = types.int;
      default = 2;
      description = "Transition step value";
    };

    transitionTypes = mkOption {
      type = types.listOf types.str;
      default = [ "random" ];
      description = "Transition animation types";
    };

    transitionDuration = mkOption {
      type = types.float;
      default = 1.5;
      description = "Duration of animation";
    };

    transitionAngles = mkOption {
      type = types.listOf types.int;
      default = lib.genList (x: x * 15) (builtins.div 360 15);
      description = "Angle of transition for specific animations";
    };

    wallpaperDir = mkOption {
      type = types.str;
      default = "";
      description = "Path to the directory of wallpaper images";
    };
  };

  config = mkIf cfg.enable {
    services.swww.enable = true;
    services.hyprpaper.enable = lib.mkForce false;
    stylix.targets.hyprpaper.enable = lib.mkForce false;

    programs.zsh.shellAliases = {
      # Skip current wallpaper
      awww-cycle = "systemctl --user kill --signal SIGUSR1 awww-cycle.service";
    };
    systemd.user.services.awww-cycle = mkIf (cfg.wallpaperDir != "") {
      Unit = {
        ConditionEnvironment = "WAYLAND_DISPLAY";
        Description = "Cycle wallpaper images using awww";
        After = [ "swww.service" ];
        PartOf = [ "swww.service" ];
      };

      Service =
        let
          awww-cycle = pkgs.writeShellApplication {
            name = "awww-cycle";
            runtimeInputs = lib.attrValues { inherit (pkgs) coreutils swww; };
            text = ''
              function skip() {
                swww query | while read -r line; do
                  if [[ -z "$line" ]]; then
                      continue
                  fi
                  MONITOR_NAME=$(echo "$line" | cut -d ':' -f 1)
                  IMAGE_PATH=$(echo "$line" | awk '{print $NF}')
                  printf "%s skipped %s\n" "$MONITOR_NAME" "$IMAGE_PATH"
                done
                return
              }
              trap skip SIGUSR1

              function wait_awww() {
                echo "Checking awww daemon is up"
                while ! swww query 2>/dev/null; do
                #while ! swww query ; do
                  # Handle: 'Error: "Socket file not found. Are you sure swww-daemon is running?"'
                  sleep 1;
                done
                echo "awww daemon is accessible"
              }

              # Any args passed to set_image are passed directly to awww img
              function cycle_image() {
                  types=(${lib.concatStringsSep " " cfg.transitionTypes})
                  angles=(${lib.concatMapStringsSep " " (a: toString a) cfg.transitionAngles})
                  mapfile -t images < <(find ${cfg.wallpaperDir}/ -maxdepth 1)

                  # shellcheck disable=SC2068
                  if ! swww img $@ \
                    "''${images[RANDOM%''${#images[@]}]}" \
                    --transition-type "''${types[RANDOM%''${#types[@]}]}" \
                    --transition-fps ${toString cfg.transitionFPS} \
                    --transition-angle "''${angles[RANDOM%''${#angles[@]}]}" \
                    --transition-duration ${toString cfg.transitionDuration};
                  then
                    echo "awww went down? awww img call failed"
                    wait_awww
                  fi
              }

              wait_awww

              while true; do
                ${
                  if cfg.cyclePerMonitor then
                    ''
                      readarray -t monitors < <(swww query | cut -d ":" -f 2)
                      for m in "''${monitors[@]}"; do
                        cycle_image -o "$m"
                      done
                    ''
                  else
                    "cycle_image"
                }

                sleep ${toString cfg.interval}
                wait $!
              done
            '';
          };
        in
        {
          Type = "simple";
          Restart = "always";
          RestartSec = 1;
          ExecStart = lib.getExe' awww-cycle "awww-cycle";
        };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
