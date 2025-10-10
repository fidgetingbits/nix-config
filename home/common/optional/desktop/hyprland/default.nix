{
  config,
  pkgs,
  lib,
  ...
}:
{

  imports =
    (map lib.custom.relativeToRoot (
      map (f: "home/common/optional/${f}") [
        "desktop/rofi.nix"
      ]
    ))
    ++ [
      ./wlogout.nix
      ./binds.nix
      ./hyprlock.nix
    ];

  # Prefer swww, and avoid hyprpaper crash loop
  services.hyprpaper.enable = lib.mkForce false;
  stylix.targets.hyprpaper.enable = lib.mkForce false;

  wayland.windowManager.hyprland = {
    enable = true;
    systemd = {
      enable = true;
      # This will expose things like XDG_DATA_DIRS to systemd services, which we want
      # FIXME: Make this a more granular list
      variables = [ "--all" ];
    };
    plugins = [
      pkgs.hyprlandPlugins.hy3
    ];
    settings = {
      debug = {
        disable_logs = false;
      };
      env = [
      ];

      #
      # ========== Monitor ==========
      #
      # parse the monitor spec defined in nix-config/home/<user>/<host>.nix
      monitor = (
        map (
          m:
          "${m.name},${
            if m.enabled then
              "${toString m.width}x${toString m.height}@${toString m.refreshRate}"
              + ",${toString m.x}x${toString m.y}"
              + ",${toString m.scale}"
              + ",transform,${toString m.transform}"
              + ",vrr,${toString m.vrr}"
            else
              "disable"
          }"
        ) (config.monitors)
      );

      input = {
        follow_mouse = 2;
        touchpad = {
          natural_scroll = true; # invert touchpad scrolling
          disable_while_typing = true;
          clickfinger_behavior = true; # two-finger right click
        };
      };

      gestures = {
        workspace_swipe = true;
        workspace_swipe_fingers = 3;
        workspace_swipe_distance = 100;
        workspace_swipe_create_new = true;
      };
      exec-once = [
      ];

      general.layout = "hy3";
      plugin = {
        hy3 = { };
      };
    };

    # FIXME: Implement a smarter window focus for single monitor where moving right/left will swap worksapces if already on the edge. There is something similar ish here:
    # https://github.com/DoMondo/dotfiles/blob/2b32ce2290ba28c809c099dc1934c361c4dfb63a/.hyprland_functions/move_focus.sh#L38
  };

  programs.zsh.shellAliases = {
    hc = "hyprctl";
    hcm = "hyprctl monitors";
  };

}
