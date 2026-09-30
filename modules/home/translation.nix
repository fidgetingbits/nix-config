# Can get zhuyin cc-cedict library from here
# https://github.com/MarvNC/cc-cedict-yomitan/releases/tag/2026-09-23
{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.translation;
  toTOML = (pkgs.formats.toml { }).generate "config.toml";
in
{
  options.${namespace}.translation = {
    enable = lib.mkEnableOption "Add translation tooling";
  };

  config = lib.mkIf cfg.enable {
    # To generate mandarin subtitles for video
    # whisper-ctranslate2 <video> --model large-v3 --language zh --output_format srt
    home.packages = lib.attrValues {
      inherit (pkgs.unstable)
        yt-dlp
        whisper-ctranslate2
        whisperx
        ;
      # NOTE: voxtype is coming from an external flake via overlay, so we don't want
      # pkgs.unstable to get the latest
      inherit (pkgs)
        voxtype
        ;
    };
    xdg.configFile."voxtype/config.toml".source = toTOML {
      state_file = "auto";

      hotkey.enabled = false;

      audio = {
        device = "default";
        sample_rate = 16000;
        max_duration_secs = 60;
      };

      whisper = {
        model = "base.en";
        language = "en";
      };

      output = {
        mode = "type";
        fallback_to_clipboard = true;

        notifications = {
          on_recording_start = true;
          on_recording_stop = true;
          on_transcription = false;
        };
      };
      osd.enabled = false;
    };

    systemd.user.services.voxtype = lib.mkForce {
      Unit = {
        Description = "Voxtype push-to-talk voice-to-text daemon";
        Documentation = "https://voxtype.io";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        # See overlay for GPU-specific binary setting
        ExecStart = "${pkgs.voxtype}/bin/voxtype daemon";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

  };
}
