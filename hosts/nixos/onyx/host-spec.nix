{ inputs, lib, ... }:
{
  hostSpec = {
    hostName = "onyx";
    primaryUsername = "aa";
    isWork = (lib.mkOverride 100) true;
    voiceCoding = (lib.mkOverride 100) false;
    useYubikey = (lib.mkOverride 100) true;
    useWayland = (lib.mkOverride 100) true;
    useWindowManager = (lib.mkOverride 100) true;
    isAutoStyled = (lib.mkOverride 100) true;
    useNeovimTerminal = (lib.mkOverride 100) true;
    hdr = (lib.mkOverride 100) true;
    scaling = (lib.mkOverride 100) "2";
    isProduction = (lib.mkOverride 100) true;
    useAtticCache = (lib.mkOverride 100) true;
    isDevelopment = (lib.mkOverride 100) true;
    isRoaming = (lib.mkOverride 100) true;
    isAdmin = (lib.mkOverride 100) true;
    users = (lib.mkOverride 100) [
      "aa"
    ];
    wallpaper = "${inputs.nix-assets}/images/wallpapers/astronaut.webp";
    defaultDesktop = "niri-uwsm";
    persistFolder = (lib.mkOverride 100) "";
  };
}
