{ inputs, lib, ... }:
{
  hostSpec = {
    hostName = "moon";
    users = lib.mkForce [
      "admin"
      "ca"
    ];
    primaryUsername = lib.mkForce "admin";
    primaryDesktopUsername = lib.mkForce "ca";
    # FIXME: deprecate this
    username = lib.mkForce "admin";

    # System type flags
    isWork = lib.mkForce false;
    isProduction = lib.mkForce true;
    isRemote = lib.mkForce true;
    isImpermanent = lib.mkForce true;

    # Functionality
    # FIXME: Separate this out to allow yubikey for incoming auth but not physical yubikey plugged in
    useYubikey = lib.mkForce false;
    useNeovimTerminal = lib.mkForce true;
    useAtticCache = lib.mkForce false;

    # Graphical
    defaultDesktop = "gnome";
    useWayland = lib.mkForce true;
    hdr = lib.mkForce true;
    scaling = lib.mkForce "2";
    isAutoStyled = lib.mkForce true;
    wallpaper = "${inputs.nix-assets}/images/wallpapers/botanical_garden.webp";
    persistFolder = lib.mkForce "/persist";
    timeZone = lib.mkForce "America/Edmonton";
  };

}
