{ config, pkgs, ... }:
{
  imports = [ ./binds.nix ];
  wayland.windowManager.hyprland = {
    enable = true;
    plugins = [
      pkgs.hyprlandPlugins.hy3
    ];
    settings = {
      debug = {
        disable_logs = false;
      };
      input = {
        follow_mouse = 2;
        touchpad = {
          disable_while_typing = true;
        };
      };
      exec-once = [
        ''${pkgs.networkmanagerapplet}/bin/nm-applet --indicator''
        ''${pkgs.blueman}/bin/blueman-applet''
      ];

      general.layout = "hy3";
      plugin = {
        hy3 = { };
      };
    };

  };

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
