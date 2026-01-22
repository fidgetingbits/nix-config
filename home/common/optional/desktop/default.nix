{ ... }:
{
  # FIXME: This should import based on wayland or not if it ever matters
  imports = [
    ./hyprland
    ./gnome
    ./niri
    ./wayland

    ########## Utilities ##########
    ./rofi.nix
    ./wlogout.nix
    ./hyprlock.nix

    ./kanshi.nix
    ./waybar.nix
  ];

  home.packages = [
  ];
}
