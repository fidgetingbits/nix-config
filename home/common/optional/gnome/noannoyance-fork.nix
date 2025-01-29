{ pkgs, ... }:
{
  home.packages = [ pkgs.gnomeExtensions.noannoyance-fork ];
  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = [ "noannoyance@daase.net" ];
    };
  };
}
