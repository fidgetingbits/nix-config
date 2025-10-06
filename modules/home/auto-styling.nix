{
  pkgs,
  lib,
  config,
  ...
}:
let
  cursorSize = 30;
in
{
  #  imports = [
  #    inputs.stylix.homeModules.stylix
  #  ];

  config = lib.mkIf config.hostSpec.isAutoStyled {
    stylix.targets.zellij.enable = true;

    # FIXME: This whole part should maybe move to a cursor.nix
    stylix = {
      cursor = lib.mkForce {
        package = pkgs.rose-pine-cursor;
        name = "BreezeX-RosePine-Linux";
        size = cursorSize;
      };
    };
    # If we don't want to use hyprcursor package(below), could just use the following
    # to set the env values instead
    # home.cursorPointer.hyprcursor.enable = true;

    # Waybar can't use hyprcursor files, so we set the xcursor version via stylix, and
    # manually install hyprcursor version below.
    home.packages = [ pkgs.rose-pine-hyprcursor ];
    wayland.windowManager.hyprland.settings.env = [
      "HYPRCURSOR_THEME,rose-pine-hyprcursor"
      "HYPRCURSOR_SIZE,${toString cursorSize}"
    ];
  };
}
