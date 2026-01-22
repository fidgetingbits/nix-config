{
  config,
  osConfig,
  lib,
  ...
}:
{

  imports = [
    # Extra settings
    ./binds.nix
    ./rules.nix

    # Hyprland utilities
    ./preview-share-picker.nix
    #./pyperland.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    systemd = {
      enable = true;
      # This will expose things like XDG_DATA_DIRS to systemd services, which we want
      # FIXME: Make this a more granular list
      variables = [ "--all" ];
    };
    plugins = [
    ];
    settings = {
      debug = {
        disable_logs = true;
      };
      env = [
      ];
      ecosystem = {
        no_update_news = true;
        no_donation_nag = true;
      };

      #
      # ========== Monitor ==========
      #
      # parse the monitor spec defined in nix-config/home/<user>/<host>.nix
      monitor =
        osConfig.monitors
        |> lib.mapAttrsToList (
          name: value:
          "${name},${
            if value.enabled then
              "${toString value.width}x${toString value.height}@${toString value.refreshRate}"
              + ",${toString value.x}x${toString value.y}"
              + ",${toString value.scale}"
              + ",transform,${toString value.transform}"
              + ",vrr,${toString value.vrr}"
            else
              "disable"
          }"
        );

      # Mouse/Touchpad
      input = {
        follow_mouse = 2;
        touchpad = {
          natural_scroll = true; # invert touchpad scrolling
          disable_while_typing = true;
          clickfinger_behavior = true; # two-finger right click
        };
      };

      gestures = {
        workspace_swipe_touch = true;
        workspace_swipe_distance = 100;
        workspace_swipe_create_new = true;
        gesture = [ "3, horizontal, workspace" ];
      };

      # Ricing
      decoration = {
        fullscreen_opacity = 1.0;
        shadow = {
          enabled = true;
          range = 2;
          sharp = true;
        };
      };

      exec-once = [
      ]
      ++ lib.optional config.introdus.services.awww.enable "swww img ${osConfig.hostSpec.wallpaper}";

    };

    # FIXME: Implement a smarter window focus for single monitor where moving right/left will swap workspaces if already on the edge. There is something similar ish here:
    # https://github.com/DoMondo/dotfiles/blob/2b32ce2290ba28c809c099dc1934c361c4dfb63a/.hyprland_functions/move_focus.sh#L38
  };

  programs.zsh.shellAliases = {
    hc = "hyprctl";
    hcm = "hyprctl monitors";
  };

}
