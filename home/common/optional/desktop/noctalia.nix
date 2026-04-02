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

  # FIXME: Remove once everything else is on noctalia
  programs.waybar = {
    enable = lib.mkForce false;
  };

  programs.noctalia-shell = {
    enable = true;
  };
}
