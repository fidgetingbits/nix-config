# This module automatically gets loaded for any host that is a desktop
# including locally and remotely managed
{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.hostSpec.isDesktop {
    introdus.services.silent-sddm.enable = true;
  };
}
