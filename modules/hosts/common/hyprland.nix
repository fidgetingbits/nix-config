{ pkgs, ... }:
{
  programs.hyprland = {
    package = pkgs.unstable.hyprland;
    enable = true;
    withUWSM = true; # systemd management of hyprland
  };

  environment.systemPackages = [
  ];
}
