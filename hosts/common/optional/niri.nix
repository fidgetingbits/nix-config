{ lib, pkgs, ... }:
{
  programs.niri = {
    enable = true;
    package = pkgs.unstable.niri;
  };
  environment.systemPackages = lib.attrValues {
    inherit (pkgs)
      xwayland-satellite # xwayland support
      ;
  };
  programs.uwsm = {
    enable = true;
    waylandCompositors = {
      niri = {
        prettyName = "niri";
        comment = "Niri compositor managed by UWSM";
        binPath = "${pkgs.niri}/bin/niri-session";
      };
    };
  };
}
