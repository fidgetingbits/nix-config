{ pkgs, ... }:
{
  # FIXME: 2026.10.22 speechSupport is is busted on unstable
  home.packages = [ (pkgs.unstable.calibre.override { speechSupport = false; }) ];
}
