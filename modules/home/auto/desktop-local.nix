# This module automatically gets loaded for any locally managed host
# that is a desktop
{
  osConfig,
  lib,
  ...
}:
{
  config = lib.mkIf (osConfig.hostSpec.isDesktop && osConfig.hostSpec.isLocal) {
    introdus.services.yubikey-touch-detector = {
      enable = true;
      notificationSound = true;
    };
  };
}
