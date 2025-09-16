# NOTE: Actions prepended with `hy3;` are specific to the hy3 hyprland plugin
{
  #config,
  lib,
  pkgs,
  ...
}:
{
  programs.wlogout = {
    enable = true;
  };

  wayland.windowManager.hyprland.settings =
    let
      mainMod = "SUPER";
    in
    {
      # Reference of supported bind flags: https://wiki.hyprland.org/Configuring/Binds/#bind-flags

      #
      # ========== Mouse Binds ==========
      #
      bindm = [
        # hold alt + leftlclick  to move/drag active window
        "${mainMod},mouse:272,movewindow"
        # hold alt + rightclick to resize active window
        "${mainMod},mouse:273,resizewindow"
      ];

      #
      # ========== Repeat Binds ==========
      #
      binde =
        let
          pactl = lib.getExe' pkgs.pulseaudio "pactl"; # installed via /hosts/common/optional/audio.nix
        in
        [
          # Resize active window 5 pixels in direction
          "Control_L&Shift_L&Alt_L, h, resizeactive, -5 0"
          "Control_L&Shift_L&Alt_L, j, resizeactive, 0 5"
          "Control_L&Shift_L&Alt_L, k, resizeactive, 0 -5"
          "Control_L&Shift_L&Alt_L, l, resizeactive, 5 0"

          #FIXME: repeat is not working for these
          # Volume - Output
          ", XF86AudioRaiseVolume, exec, ${pactl} set-sink-volume @DEFAULT_SINK@ +5%"
          ", XF86AudioLowerVolume, exec, ${pactl} set-sink-volume @DEFAULT_SINK@ -5%"
          # Volume - Input
          ", XF86AudioRaiseVolume, exec, ${pactl} set-source-volume @DEFAULT_SOURCE@ +5%"
          ", XF86AudioLowerVolume, exec, ${pactl} set-source-volume @DEFAULT_SOURCE@ -5%"
        ];

      #
      # ========== One-shot Binds ==========
      #
      bind =
        let
          workspaces = [
            "1"
            "2"
            "3"
            "4"
            "5"
            "6"
            "7"
            "8"
            "9"
            "10"
            # FIXME: Why the F# keys?
            "F1"
            "F2"
            "F3"
            "F4"
            "F5"
            "F6"
            "F7"
            "F8"
            "F9"
            "F10"
            "F11"
            "F12"
          ];
          # Map keys (arrows and hjkl) to hyprland directions (l, r, u, d)
          directions = rec {
            left = "l";
            right = "r";
            up = "u";
            down = "d";
            h = left;
            l = right;
            k = up;
            j = down;
          };
          pactl = lib.getExe' pkgs.pulseaudio "pactl";
          playerctl = lib.getExe' pkgs.playerctl "playerctl";
          #terminal = config.home.sessionVariables.TERM;
          #editor = config.home.sessionVariables.EDITOR;
        in
        lib.flatten [

          #
          # ========== Quick Launch ==========
          #
          "${mainMod},space,exec,rofi -show drun"
          "${mainMod} SHIFT,space,exec,rofi -show run"
          "${mainMod},tab,exec,rofi -show window"

          "${mainMod},return,exec,ghostty"
          "${mainMod},v,exec,ghostty neovim"

          #
          # ========== Media Controls ==========
          #
          # see "binde" above for volume ctrls that need repeat binding
          # Output
          ", XF86AudioMute, exec, ${pactl} set-sink-mute @DEFAULT_SINK@ toggle"
          # Input
          ", XF86AudioMute, exec, ${pactl} set-source-mute @DEFAULT_SOURCE@ toggle"
          # Player
          ", XF86AudioPlay, exec, ${playerctl} --ignore-player=firefox,chromium,brave play-pause"
          ", XF86AudioNext, exec, ${playerctl} --ignore-player=firefox,chromium,brave next"
          ", XF86AudioPrev, exec, ${playerctl} --ignore-player=firefox,chromium,brave previous"

          #
          # ========== Windows and Groups ==========
          #
          #NOTE: window resizing is under "Repeat Binds" above

          # Close the focused/active window
          "${mainMod} SHIFT,q,hy3:killactive"
          #"SHIFTALT,q,killactive"

          # Fullscreen
          #"ALT,f,fullscreen,0" # 0 - fullscreen (takes your entire screen), 1 - maximize (keeps gaps and bar(s))
          "${mainMod},f,fullscreenstate,2 -1" # `internal client`, where `internal` and `client` can be -1 - current, 0 - none, 1 - maximize, 2 - fullscreen, 3 - maximize and fullscreen
          # Float
          "${mainMod} SHIFT,F,togglefloating"
          # Pin Active Floating window
          "${mainMod} SHIFT,p, pin, active" # pins a floating window (i.e. show it on all workspaces)

          # Splits groups
          "${mainMod},v,hy3:makegroup,v" # make a vertical split
          "${mainMod} SHIFT,v,hy3:makegroup,h" # make a horizontal split
          "${mainMod},x,hy3:changegroup,opposite" # toggle btwn splits if untabbed
          "${mainMod},s,togglesplit"

          # Tab groups
          "${mainMod},g,hy3:changegroup,toggletab" # tab or untab the group
          #"ALT,t,lockactivegroup,toggle"
          "${mainMod},apostrophe,changegroupactive,f"
          "${mainMod} SHIFT,apostrophe,changegroupactive,b"

          #
          # ========== Workspaces ==========
          #
          # Change workspace
          (map (
            n: if n == "10" then "${mainMod},0,workspace,name:10" else "${mainMod},${n},workspace,name:${n}"
          ) workspaces)

          # Special/scratch
          "${mainMod},y, togglespecialworkspace"
          "${mainMod} SHIFT,y,movetoworkspace,special"

          # Move window to workspace
          (map (
            n:
            if n == "10" then
              "${mainMod} SHIFT,0,hy3:movetoworkspace,name:10"
            else
              "${mainMod} SHIFT,${n},hy3:movetoworkspace,name:${n}"
          ) workspaces)

          # Move focus from active window to window in specified direction
          #(lib.mapAttrsToList (key: direction: "${mainMod},${key}, exec, customMoveFocus ${direction}") directions)
          (lib.mapAttrsToList (
            key: direction: "${mainMod},${key},hy3:movefocus,${direction},warp"
          ) directions)

          # Move windows
          #(lib.mapAttrsToList (key: direction: "${mainMod} SHIFT,${key}, exec, customMoveWindow ${direction}") directions)
          (lib.mapAttrsToList (
            key: direction: "${mainMod} SHIFT,${key},hy3:movewindow,${direction}"
          ) directions)

          # Move workspace to monitor in specified direction
          # FIXME: Revisit this keybinding
          (lib.mapAttrsToList (
            key: direction: "CTRLSHIFT,${key},movecurrentworkspacetomonitor,${direction}"
          ) directions)

          #
          # ========== Monitors==========
          #
          "${mainMod}, m, exec, toggleMonitors"
          "${mainMod}, n, exec, toggleMonitorsNonPrimary"

          #
          # ========== Misc ==========
          #
          "${mainMod} SHIFT,r,exec,hyprctl reload" # reload the configuration file
          "${mainMod},l,exec,hyprlock" # lock the wm
          "${mainMod},e,exec,wlogout" # lock the wm
        ];
    };
}
