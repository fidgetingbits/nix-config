{
  pkgs,
  lib,
  ...
}:
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
  ];

  programs.mpv = {
    enable = true;
    package = pkgs.mpv.override {
      mpv-unwrapped = pkgs.mpv-unwrapped.override {
        # FIXME: This tries to compile firefox... maybe becomes of rocmSupport?
        ffmpeg = pkgs.ffmpeg-full;
      };

      scripts = lib.attrValues {
        # FIXME: See settings here: https://github.com/donovanglover/nix-config/blob/8b3a33448356b40da856a44cf8f45b3d563466d2/home/mpv.nix#L26
        inherit (pkgs.mpvScripts)
          mpris # control via dbus
          uosc # mouse proximity based UI
          thumbfast # quick thumbnailing preview
          ;
      };
    };
  };
}
