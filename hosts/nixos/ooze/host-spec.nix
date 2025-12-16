{ lib, ... }:
{
  hostSpec = {
    hostName = "ooze";
    isProduction = lib.mkForce true;
    isServer = lib.mkForce true;
    persistFolder = lib.mkForce "/persist";
    useWindowManager = lib.mkForce false;
  };
}
