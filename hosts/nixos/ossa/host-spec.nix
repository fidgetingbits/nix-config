{ inputs, lib, ... }:
{
  hostSpec = {
    hostName = "ossa";
    primaryUsername = (lib.mkOverride 100) "aa";

    # System type flags
    isWork = (lib.mkOverride 100) true;
    isDevelopment = (lib.mkOverride 100) true;
    isRoaming = (lib.mkOverride 100) true;
    isAdmin = (lib.mkOverride 100) true;
    isAutoStyled = (lib.mkOverride 100) true;
    isProduction = (lib.mkOverride 100) true;
    isAmdGpu = true;

    isImpermanent = (lib.mkOverride 100) true;
    persistFolder = (lib.mkOverride 100) "/persist";

    # Functionality
    useNeovimTerminal = (lib.mkOverride 100) true;
    useAtticCache = (lib.mkOverride 100) true;
    useYubikey = (lib.mkOverride 100) true;

    # Desktop
    useWayland = (lib.mkOverride 100) true;
    useWindowManager = (lib.mkOverride 100) true;
    scaling = (lib.mkOverride 100) "2";
    wallpaper = "${inputs.nix-assets}/images/wallpapers/astronaut.webp";
    defaultDesktop = "niri-uwsm";
  };
}
