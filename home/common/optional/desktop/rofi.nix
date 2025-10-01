{ config, pkgs, ... }:
{
  programs.rofi = {
    enable = true;
    package = if config.hostSpec.useWayland then pkgs.rofi-wayland else pkgs.rofi;
  };
}
