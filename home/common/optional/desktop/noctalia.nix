{
  inputs,
  lib,
  # pkgs,
  ...
}:
{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.waybar = {
    enable = lib.mkForce false;
  };
  programs.noctalia-shell = {
    enable = true;
  };
}
