{ pkgs, ... }:
{
  home.packages = [ pkgs.gnomeExtensions.tray-icons-reloaded ];
  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = [ "blur-my-shell@aunetx" ];
    };
    "org/gnome/shell/extensions/blur-my-shell" = {
      icon-size = 16;
      icons-limit = 5;
    };
  };
}
