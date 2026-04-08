{ pkgs, lib, ... }:
{
  # FIXME: This should import based on wayland or not if it ever matters
  imports = [
    ./gnome
    ./niri
    ./wayland

    ########## Shell ##########
    ./noctalia

    ########## Utilities ##########
    ./rofi.nix
    ./kanshi.nix
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
