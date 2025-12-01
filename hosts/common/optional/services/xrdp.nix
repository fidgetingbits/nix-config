{
  pkgs,
  ...
}:
{
  # FIXME: Make the gnome parts dependent on primary desktop?
  services.xrdp.enable = true;
  services.xrdp.defaultWindowManager = "${pkgs.gnome-session}/bin/gnome-session"; # gnome wayland session
  services.gnome.gnome-remote-desktop.enable = true;
  services.displayManager.autoLogin.enable = false;
  services.getty.autologinUser = null;
  networking.firewall.allowedTCPPorts = [ 3389 ];
}
