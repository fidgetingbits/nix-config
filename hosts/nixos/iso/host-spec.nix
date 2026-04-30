{
  lib,
  secrets,
  ...
}:
{
  hostSpec = {
    primaryUsername = "aa";
    username = "aa";
    hostName = "iso";
    isProduction = lib.mkForce false;
    isMinimal = lib.mkForce true;
    networking = secrets.networking; # Needed because we don't use host/common/core for iso
  };
}
