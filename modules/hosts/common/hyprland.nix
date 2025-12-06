{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.desktops.hyprland;
in
{
  options = {
    desktops.hyprland.enable = lib.mkEnableOption "Enable hyprland and related functionality";
  };

  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      package = pkgs.unstable.hyprland;
      enable = true;
      withUWSM = true; # systemd management of hyprland
    };
  };
}
