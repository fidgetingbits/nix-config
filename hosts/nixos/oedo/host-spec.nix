{ lib, ... }:
let
  inherit (lib.custom) highPrio;
in
{
  hostSpec = {
    hostName = "oedo";
    primaryUsername = "aa";
    isWork = (lib.mkOverride 100) false;
    voiceCoding = (lib.mkOverride 100) false;
    useYubikey = (lib.mkOverride 100) true;
    wifi = (lib.mkOverride 100) true;
    useNeovimTerminal = (lib.mkOverride 100) true;
    persistFolder = (lib.mkOverride 100) "/persist";
    isImpermanent = (lib.mkOverride 100) true;
    isProduction = (lib.mkOverride 100) true;
    isAutoStyled = (lib.mkOverride 100) true;
    isDevelopment = (lib.mkOverride 100) true;
    isAdmin = (lib.mkOverride 100) true;

    useAtticCache = highPrio true;

    useWayland = true;
    defaultDesktop = "niri-uwsm";

    isAmdGpu = true;
    useRocm = (lib.mkOverride 100) true;
  };
}
