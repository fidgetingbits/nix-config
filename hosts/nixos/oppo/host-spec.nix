{ inputs, lib, ... }:
{

  # Host Specification
  hostSpec = {
    # Read current directory to get the host name
    hostName = "oppo";
    primaryUsername = (lib.mkOverride 100) "aa";
    isWork = (lib.mkOverride 100) false;
    useYubikey = (lib.mkOverride 100) true;
    isAutoStyled = (lib.mkOverride 100) true;
    wifi = (lib.mkOverride 100) false;
    useNeovimTerminal = (lib.mkOverride 100) true;
    hdr = (lib.mkOverride 100) true;
    scaling = (lib.mkOverride 100) "2";
    isProduction = (lib.mkOverride 100) true;
    isDevelopment = (lib.mkOverride 100) true;
    isIntrodusDev = (lib.mkOverride 100) false;
    isImpermanent = (lib.mkOverride 100) true;

    persistFolder = (lib.mkOverride 100) "/persist";
    useWayland = (lib.mkOverride 100) true;
    users = (lib.mkOverride 100) [
      "aa"
      "media"
    ];
    wallpaper = "${inputs.nix-assets}/images/wallpapers/spirited_away_reflection.webp";
    isAMDGpu = true;
  };

}
