# This module automatically gets loaded for any host that is a desktop
# including locally and remotely managed
{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.hostSpec.isDesktop {
    introdus = {
      services.audio.enable = true;
      services.silent-sddm.enable = true;
    };

    # Wayland only. Fix xdg-desktop-portal-gnome not always starting
    # despite being available. Breaks ScreenCast functionality
    # on some systems
    systemd.user.services.xdg-desktop-portal = {
      overrideStrategy = "asDropin";
      unitConfig = {
        Wants = [ "xdg-desktop-portal-gnome.service" ];
        After = [ "xdg-desktop-portal-gnome.service" ];
      };
    };
  };
}
