{ inputs, lib, ... }:
{

  # Host Specification
  hostSpec = {
    # Read current directory to get the host name
    hostName = "oppo";
    isWork = lib.mkForce false;
    useYubikey = lib.mkForce true;
    isAutoStyled = lib.mkForce true;
    wifi = lib.mkForce false;
    useNeovimTerminal = lib.mkForce true;
    hdr = lib.mkForce true;
    scaling = lib.mkForce "2";
    isProduction = lib.mkForce true;
    isDevelopment = lib.mkForce true;
    persistFolder = lib.mkForce "/persist";
    useWayland = lib.mkForce true;
    users = lib.mkForce [
      "aa"
      "media"
    ];
    wallpaper = "${inputs.nix-assets}/images/wallpapers/spirited_away_reflection.webp";
  };

}
