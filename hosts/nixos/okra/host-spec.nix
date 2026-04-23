{ lib, ... }:
{
  hostSpec = {
    hostName = "okra";
    primaryUsername = (lib.mkOverride 100) "aa";

    isProduction = lib.mkForce false;
    persistFolder = lib.mkForce "/persist";
    isImpermanent = lib.mkForce true;
  };
}
