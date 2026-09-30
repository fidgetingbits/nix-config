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
  };
}
