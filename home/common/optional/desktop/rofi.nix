{ config, pkgs, ... }:
{
  home.packages = [
    pkgs.rofi-copyq
  ];
  programs.rofi = {
    enable = true;
    package = if config.hostSpec.useWayland then pkgs.rofi-wayland else pkgs.rofi;
  };
}
