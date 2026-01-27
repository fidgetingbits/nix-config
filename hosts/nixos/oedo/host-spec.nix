{ lib, ... }:
{
  hostSpec = {
    hostName = "oedo";
    isWork = lib.mkForce false;
    voiceCoding = lib.mkForce false;
    useYubikey = lib.mkForce true;
    wifi = lib.mkForce true;
    useNeovimTerminal = lib.mkForce false;
    persistFolder = lib.mkForce "/persist";
    isProduction = lib.mkForce true;
    isAutoStyled = lib.mkForce true;
    isDevelopment = lib.mkForce true;
    isAdmin = lib.mkForce true;
    # FIXME: We should have like "desktop" = "hyprland" and have that auto enable the rest?
    defaultDesktop = "hyprland-uwsm";
    useWayland = true;
    isAmdGpu = true;
  };
}
