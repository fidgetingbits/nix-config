{ lib, ... }:
{
  hostSpec = {
    hostName = "myth";
    users = lib.mkForce [
      "admin"
      "pa"
      "borg"
    ];
    primaryUsername = lib.mkForce "admin";
    # FIXME: deprecate this
    username = lib.mkForce "admin";

    # System type flags
    isWork = lib.mkForce false;
    isProduction = lib.mkForce true;
    isRemote = lib.mkForce true;
    isImpermanent = lib.mkForce true;
    isServer = lib.mkForce true;
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
