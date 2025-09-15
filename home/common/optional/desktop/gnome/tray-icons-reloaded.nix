{ pkgs, ... }:
{
  home.packages = [ pkgs.gnomeExtensions.tray-icons-reloaded ];
  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = [ "trayIconsReloaded@selfmade.pl" ];
    };
    # If you want to tweak this stuff, run `dconf dump /org/gnome/shell/extensions/trayIconsReloaded/` to get the
    # current settings
    # If you don't know the setting use "extensions" app to tweak settings and then run the above command after,
    # or watch for changes with `dconf watch /org/gnome/shell/extensions/trayIconsReloaded/`
    "org/gnome/shell/extensions/trayIconsReloaded" = {
      icon-size = 16;
      icons-limit = 5;
    };
  };
}
