{ pkgs, lib, ... }:
let
  videoPlayers = if pkgs.stdenv.isDarwin then [ pkgs.mpv ] else [ pkgs.vlc ];
in
{
  home.packages = lib.flatten [
    (lib.attrValues { inherit (pkgs) spotify ffmpeg; })

    videoPlayers
  ];
}
