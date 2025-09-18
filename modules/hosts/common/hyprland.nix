{ ... }:
{
  programs.hyprland = {
    enable = true;
    # Use systemd management of hyprland
    withUWSM = true;
  };

  environment.systemPackages = [
  ];
}
