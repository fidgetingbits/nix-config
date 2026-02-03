{ lib, ... }:
{
  hostSpec = {
    hostName = "moth";
    users = lib.mkForce [
      "aa"
      "ta"
      "borg"
    ];
    primaryUsername = lib.mkForce "aa";
    username = lib.mkForce "aa";

    # System type flags
    isWork = lib.mkForce false;
    isProduction = lib.mkForce true;
    isRemote = lib.mkForce true;
    isServer = lib.mkForce true;
    isImpermanent = lib.mkForce true;
    isAutoStyled = lib.mkForce false;
    useWindowManager = lib.mkForce false;

    # Functionality
    useYubikey = lib.mkForce false;
    useNeovimTerminal = lib.mkForce false;
    useAtticCache = lib.mkForce false;

    # Networking
    wifi = lib.mkForce false;

    # System settings
    persistFolder = lib.mkForce "/persist";
    timeZone = lib.mkForce "America/Edmonton";
  };

}
