{ pkgs, ... }:
{
  home.packages = [
    pkgs.wl-clipboard
    pkgs.unstable.grimblast
  ];
}
