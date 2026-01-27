{ inputs, lib, ... }:
{
  hostSpec = {
    hostName = "ossa";
    isWork = lib.mkForce true;
    voiceCoding = lib.mkForce false;
    useYubikey = lib.mkForce true;
    useWayland = lib.mkForce true;
    useWindowManager = lib.mkForce true;
    isAutoStyled = lib.mkForce true;
    useNeovimTerminal = lib.mkForce true;
    scaling = lib.mkForce "2";
    isProduction = lib.mkForce true;
    useAtticCache = lib.mkForce true;
    isDevelopment = lib.mkForce true;
    isRoaming = lib.mkForce true;
    isAdmin = lib.mkForce true;
    users = lib.mkForce [
      "aa"
    ];
    wallpaper = "${inputs.nix-assets}/images/wallpapers/astronaut.webp";
    #defaultDesktop = "hyprland-uwsm";
    defaultDesktop = "niri-uwsm";
    persistFolder = lib.mkForce "/persist";
    isAmdGpu = true;
  };
}
