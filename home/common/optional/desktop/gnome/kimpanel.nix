{ pkgs, ... }:
{
  home.packages = [ pkgs.gnomeExtensions.kimpanel ];
  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = [ "kimpanel@kde.org" ];
    };
  };
}
