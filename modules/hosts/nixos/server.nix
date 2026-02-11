{
  config,
  pkgs,
  lib,
  ...
}:
lib.mkIf config.hostSpec.isServer {
  environment.systemPackages = lib.attrValues {
    inherit (pkgs)
      lm_sensors
      smartmontools
      ;
  };
}
