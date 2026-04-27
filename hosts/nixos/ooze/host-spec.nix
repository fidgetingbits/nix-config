{ lib, ... }:
{
  hostSpec = {
    hostName = "ooze";
    primaryUsername = lib.mkForce "aa";
    isProduction = lib.mkForce true;
    isServer = lib.mkForce true;
    isImpermanent = lib.mkForce true;
    persistFolder = lib.mkForce "/persist";
    useWindowManager = lib.mkForce false;
  };
}
