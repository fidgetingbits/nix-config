{
  pkgs,
  lib,
  ...
}:
let
  videoPlayers = if pkgs.stdenv.isDarwin then [ pkgs.mpv ] else [ pkgs.vlc ];
in
{
  home.packages = lib.flatten [
    (lib.attrValues {
      inherit (pkgs)
        ffmpeg
        spicetify-cli
        spotify-player
        ;
      inherit (pkgs.unstable)
        spotify # New enough to hopefully fix stack corruption spam
        ;
    })

    videoPlayers
  ];
}
