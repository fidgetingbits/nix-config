{ pkgs, ... }:
{
  home.packages = [
    pkgs.introdus.rofi-copyq
  ];
  programs.rofi = {
    enable = true;
  };
}
