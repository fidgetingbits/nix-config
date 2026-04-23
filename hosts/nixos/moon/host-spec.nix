{ inputs, lib, ... }:
{
  hostSpec = {
    hostName = "moon";
    users = (lib.mkOverride 100) [
      "admin"
      "ca"
    ];
    primaryUsername = (lib.mkOverride 100) "admin";
    primaryDesktopUsername = (lib.mkOverride 100) "ca";
    # FIXME: deprecate this
    username = (lib.mkOverride 100) "admin";

    # System type flags
    isWork = (lib.mkOverride 100) false;
    isProduction = (lib.mkOverride 100) true;
    isRemote = (lib.mkOverride 100) true;
    isImpermanent = (lib.mkOverride 100) true;

    # Functionality
    # FIXME: Separate this out to allow yubikey for incoming auth but not physical yubikey plugged in
    useYubikey = (lib.mkOverride 100) false;
    useNeovimTerminal = (lib.mkOverride 100) true;
    useAtticCache = (lib.mkOverride 100) false;

    # Graphical
    defaultDesktop = "gnome";
    useWayland = (lib.mkOverride 100) true;
    hdr = (lib.mkOverride 100) true;
    scaling = (lib.mkOverride 100) "2";
    isAutoStyled = (lib.mkOverride 100) true;
    wallpaper = "${inputs.nix-assets}/images/wallpapers/botanical_garden.webp";
    persistFolder = (lib.mkOverride 100) "/persist";
    timeZone = (lib.mkOverride 100) "America/Edmonton";
  };

}
