{
  pkgs,
  lib,
  ...
}:
{
  home.packages = lib.attrValues {
    inherit (pkgs)
      ffmpeg
      spicetify-cli
      spotify-player
      ;
    inherit (pkgs.unstable)
      spotify # New enough to hopefully fix stack corruption spam
      ;
  };
}
