{ lib, ... }:
{
  hostSpec = {
    hostName = "okra";
    isProduction = lib.mkForce false;
    persistFolder = lib.mkForce "/persist";
  };
}
