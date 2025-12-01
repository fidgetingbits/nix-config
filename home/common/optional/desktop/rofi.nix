{ pkgs, ... }:
{
  home.packages = [
    pkgs.rofi-copyq
  ];
  programs.rofi = {
    enable = true;
  };
}
