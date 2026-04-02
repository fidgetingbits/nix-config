{ inputs, lib, ... }:
let
  inherit (lib.custom) highPrio;
in
{
  hostSpec = {
    hostName = "ossa";
    users = highPrio [
      "aa"
    ];
    primaryUsername = highPrio "aa";

    # System type flags
    isWork = highPrio true;
    isDevelopment = highPrio true;
    isRoaming = highPrio true;
    isAdmin = highPrio true;
    isAutoStyled = highPrio true;
    isProduction = highPrio true;
    isAmdGpu = true;

    isImpermanent = highPrio true;
    persistFolder = highPrio "/persist";

    # Functionality
    useNeovimTerminal = highPrio true;
    useAtticCache = highPrio true;
    useYubikey = highPrio true;

    # Desktop
    useWayland = highPrio true;
    useWindowManager = highPrio true;
    scaling = highPrio "2";
    wallpaper = "${inputs.nix-assets}/images/wallpapers/astronaut.webp";
    defaultDesktop = "niri-uwsm";
  };
}
