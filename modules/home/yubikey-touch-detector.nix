# See https://github.com/berbiche/dotfiles/blob/4048a1746ccfbf7b96fe734596981d2a1d857930/modules/home-manager/yubikey-touch-detector.nix#L9
# FIXME: Send a PR to HM to add this service
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.yubikey-touch-detector;
in
{
  options.services.yubikey-touch-detector = {
    enable = lib.mkEnableOption "a tool to detect when your YubiKey is waiting for a touch";

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "--libnotify" ];
      defaultText = lib.literalExpression ''[ "--libnotify" ]'';
      description = ''
        Extra arguments to pass to the tool. The arguments are not escaped.
      '';
    };
    notificationSound = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Play sounds when the YubiKey is waiting for a touch.
      '';
    };
    notificationSoundFile = lib.mkOption {
      type = lib.types.str;
      #default = "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/window-attention.oga";
      default = "${inputs.nix-assets}/notifications/john_spartan.ogg";
      description = ''
        Path to the sound file to play when the YubiKey is waiting for a touch.
      '';
    };
  };

  # NOTE: I duplicate the services and stuff here because it doesn't exist for
  # home-manager, only for programs.yubikey-touch-detector in nixos.
  config = lib.mkIf cfg.enable {
    #programs.yubikey-touch-detector.enable = true;
    home.packages = [ pkgs.yubikey-touch-detector ];

    # Same license thing for the description here
    systemd.user.services.yubikey-touch-detector = {
      Unit = {
        Description = "Detects when your YubiKey is waiting for a touch";
      };
      Service = {
        ExecStart = "${lib.getExe' pkgs.yubikey-touch-detector "yubikey-touch-detector"} ${lib.concatStringsSep " " cfg.extraArgs}";
        Environment = [ "PATH=${lib.makeBinPath [ pkgs.gnupg ]}" ];
        Restart = "on-failure";
        RestartSec = "1sec";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    # Play sound when the YubiKey is waiting for a touch
    systemd.user.services.yubikey-touch-detector-sound =
      let
        file = cfg.notificationSoundFile;
        yubikey-play-sound = pkgs.writeShellApplication {
          name = "yubikey-play-sound";
          runtimeInputs = lib.attrValues { inherit (pkgs) coreutils mpv netcat; };
          text = ''
            socket="''${XDG_RUNTIME_DIR:-/run/user/$UID}/yubikey-touch-detector.socket"

            while true; do
                if [ ! -e "$socket" ]; then
                    printf "Waiting for YubiKey %s\n" "$socket"
                    while [ ! -e "$socket" ]; do sleep 1; done
                fi
                printf "Detected %s is up\n" "$socket"

                nc -U "$socket" | while read -r -n5 cmd; do
                  if [ "''${cmd:4:1}" = "1" ]; then
                    printf "Playing ${file}\n"
                    mpv --volume=100 ${file} > /dev/null
                  else
                    printf "Ignored yubikey command: %s\n" "$cmd"
                  fi
                done

                sleep 1
            done
          '';
        };
      in
      lib.mkIf cfg.notificationSound {
        Unit = {
          Description = "Play sound when the YubiKey is waiting for a touch";
          Requires = [ "yubikey-touch-detector.service" ];
        };
        Service = {
          ExecStart = lib.getExe' yubikey-play-sound "yubikey-play-sound";
          Restart = "on-failure";
          RestartSec = "1sec";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
  };
}
