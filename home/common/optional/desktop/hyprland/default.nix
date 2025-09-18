{ config, pkgs, ... }:
{
  imports = [
    ./binds.nix
    ./hyprlock.nix
  ];
  # Trying to figure out why no tray appears
  services.status-notifier-watcher.enable = true;
  wayland.windowManager.hyprland = {
    enable = true;
    # FIXME: Make sure if this is needed despite uswm
    systemd.variables = [ "--all" ];
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
        # FIXME: Maybe only bother setting these on laptops? Not sure it matters
        touchpad = {

          # Invert touchpad scrolling
          natural_scroll = true;

          disable_while_typing = true;
          # Allows two-finger right click
          clickfinger_behavior = true;

        };
      };

      gestures = {
        workspace_swipe = true;
        workspace_swipe_fingers = 3;
        workspace_swipe_distance = 100;
        workspace_swipe_create_new = true;
      };
      exec-once = [
        ''${pkgs.waybar}/bin/waybar''
        ''${pkgs.networkmanagerapplet}/bin/nm-applet --indicator''
        ''${pkgs.blueman}/bin/blueman-applet''
      ];

      general.layout = "hy3";
      plugin = {
        hy3 = { };
      };
    };

    # FIXME: Implement a smarter window focus for single monitor where moving right/left will swap worksapces if already on the edge. There is something similar ish here:
    # https://github.com/DoMondo/dotfiles/blob/2b32ce2290ba28c809c099dc1934c361c4dfb63a/.hyprland_functions/move_focus.sh#L38
  };

  # FIXME: Why does this get clobbered?
  programs.zsh.shellAliases = {
    hc = "hyprctl";
    hcm = "hyprctl monitors";
  };

  # FIXME: These are only used on hyprland for now, but should be main optional elsewhere

  programs.rofi = {
    enable = true;
    package = if config.hostSpec.useWayland then pkgs.rofi-wayland else pkgs.rofi;
  };
}
