{ pkgs, lib, ... }:
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

  # NOTE: thunar comes from host level atm
  home.packages = lib.attrValues {
    inherit (pkgs)
      # tools used in config
      brightnessctl
      playerctl
      wireplumber
      ;
  };
}
