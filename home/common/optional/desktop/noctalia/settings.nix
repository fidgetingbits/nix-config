# IMPORTANT: This file should copy noctalia2nix output
# Keep in mind:
# - evaluation-time values will need to be tweaked
# - output will include values from other areas (introdus) which need to be removed
{
  inputs,
  ...
}:
{
  bar = {
    order = [
      "widgets"
      "tasks"
    ];
    tasks = {
      background_opacity = 0.75;
      center = [ "taskbar" ];
      enabled = true;
      end = [ ];
      margin_ends = 500;
      position = "bottom";
      smart_auto_hide = true;
      start = [ ];
    };
    widgets = {
      background_opacity = 0.75;
      center = [ "workspaces" ];
      end = [
        "tray"
        "notifications"
        "clipboard"
        "bluetooth"
        "volume"
        "brightness"
        "battery"
        "status"
        "meeting"
        "yubikey-sound"
        "network"
      ];
      start = [
        "date"
        "clock"
        "media"
      ];
    };
  };
  calendar = {
    enabled = true;
  };
  lockscreen = {
    allow_empty_password = true;
    enabled = true;
    fingerprint = false;
  };

  # FIXME: This is gonna be box specific
  lockscreen_widgets = {
    enabled = false;
    grid = {
      cell_size = 16;
      major_interval = 4;
      visible = true;
    };
    schema_version = 2;
    widget = {
      "lockscreen-login-box@eDP-1" = {
        box_height = 196;
        box_width = 810;
        cx = 966;
        cy = 1026;
        output = "eDP-1";
        placement_height = 1208;
        placement_width = 1932;
        rotation = 0;
        settings = {
          background_color = "surface_variant";
          background_opacity = 0.88;
          background_radius = 12;
          center_password_text = false;
          input_opacity = 1;
          input_radius = 6;
          layout = "regular";
          show_caps_lock = true;
          show_keyboard_layout = true;
          show_login_button = true;
          show_media = true;
          show_session_buttons = true;
          show_unlock_hint = true;
          show_weather = true;
        };
        type = "login_box";
      };
    };
    # FIXME: This is gonna be box specific
    widget_order = [ "lockscreen-login-box@eDP-1" ];
  };
  plugin_settings = {
    "gabedunn/voxtype" = {
      show_extended = true;
    };
  };
  plugins = {
    auto_update = "all";
    # FIXME:: voxtype should only be enable don some systems
    enabled = [
      "gabedunn/voxtype"
      "fidgetingbits/voxtype-meeting"
      "thepunkoff/pomodoro"
    ];
    source = [
      {
        enabled = true;
        kind = "git";
        location = "https://github.com/noctalia-dev/community-plugins";
        name = "community";
      }
      {
        enabled = true;
        kind = "git";
        location = "https://github.com/noctalia-dev/official-plugins";
        name = "official";
      }
      {
        enabled = true;
        kind = "path";
        location = "~/dev/noctalia/community-plugins";
        name = "fidgetingbits-plugins";
      }
    ];
  };
  shell = {
    external_ip_enabled = true;
    niri_overview_type_to_launch_enabled = true;
    session = {
      actions = [
        {
          action = "lock";
          countdown_seconds = 0;
          enabled = true;
          shortcut = "1";
          variant = "default";
        }
        {
          action = "logout";
          countdown_seconds = 0;
          enabled = true;
          shortcut = "2";
          variant = "default";
        }
        {
          action = "lock_and_suspend";
          countdown_seconds = 0;
          enabled = true;
          label = "Suspend";
          shortcut = "3";
          variant = "default";
        }
        {
          action = "reboot";
          countdown_seconds = 0;
          enabled = true;
          shortcut = "4";
          variant = "default";
        }
        {
          action = "shutdown";
          countdown_seconds = 0;
          enabled = true;
          shortcut = "5";
          variant = "destructive";
        }
      ];
    };
  };
  theme = {
    builtin = "Catppuccin";
    mode = "dark";
    source = "builtin";
  };
  wallpaper = {
    default = {
      path = "${inputs.nix-assets}/images/wallpapers/astronaut.webp";
    };
    enabled = true;
  };
  widget = {
    battery = {
      hide_when_full = true;
      label_content = "time";
    };
    brightness = {
      show_label = false;
    };
    date = {
      format = "{:%Y.%m.%d}";
    };
    meeting = {
      type = "fidgetingbits/voxtype-meeting:meeting";
    };
    status = {
      type = "gabedunn/voxtype:status";
    };
    taskbar = {
      group_by_workspace = true;
      group_single_icon_per_app = true;
      hide_empty_workspaces = true;
      inactive_opacity = 0.5;
      minimal = true;
      show_workspace_label = false;
    };
    tray = {
      hidden = [
        "blueman"
        "easyeffects"
        "copyq"
      ];
    };
    volume = {
      show_label = false;
    };
  };
}
