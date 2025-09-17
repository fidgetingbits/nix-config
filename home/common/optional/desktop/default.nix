{ config, ... }:
{
  services.displayManager.defaultSession = config.hostSpec.defaultDesktop;
}
