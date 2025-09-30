{ ... }:
{
  programs.hyprland = {
    enable = true;
    withUWSM = true; # systemd management of hyprland
  };

  environment.systemPackages = [
  ];
}
