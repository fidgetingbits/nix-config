{ inputs, lib, ... }:
{
  hostSpec = {
    hostName = "ossa";
    users = lib.mkForce [
      "aa"
    ];
    primaryUsername = lib.mkForce "aa";

    # System type flags
    isWork = lib.mkForce true;
    isDevelopment = lib.mkForce true;
    isRoaming = lib.mkForce true;
    isAdmin = lib.mkForce true;
    isAutoStyled = lib.mkForce true;
    isProduction = lib.mkForce true;
    isAmdGpu = true;

    isImpermanent = lib.mkForce true;
    persistFolder = lib.mkForce "/persist";

    # Functionality
    useNeovimTerminal = lib.mkForce true;
    useAtticCache = lib.mkForce true;
    useYubikey = lib.mkForce true;

    # Desktop
    useWayland = lib.mkForce true;
    useWindowManager = lib.mkForce true;
    scaling = lib.mkForce "2";
    wallpaper = "${inputs.nix-assets}/images/wallpapers/astronaut.webp";
    defaultDesktop = "niri-uwsm";
  };
}
