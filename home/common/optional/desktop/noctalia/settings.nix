{
  inputs,
  ...
}:
{
  bar = {
    widgets = {
      background_opacity = 0.75;
      center = [
        "session"
        "workspaces"
        "control-center"
      ];
      end = [
        "tray"
        "notifications"
        "clipboard"
        "network"
        "bluetooth"
        "volume"
        "brightness"
        "battery"
        "voxtype"
        "voxtype-meeting"
      ];
      start = [
        "date"
        "clock"
        "media"
      ];
    };
  };

  shell = {
    external_ip_enabled = true;
    niri_overview_type_to_launch_enabled = true;
    session = {
      actions = [
        {
          action = "lock";
          countdown_seconds = 0.0;
          enabled = true;
          shortcut = "1";
          variant = "default";
        }
        {
          action = "logout";
          countdown_seconds = 0.0;
          enabled = true;
          shortcut = "2";
          variant = "default";
        }
        {
          action = "lock_and_suspend";
          countdown_seconds = 0.0;
          enabled = true;
          label = "Suspend";
          shortcut = "3";
          variant = "default";
        }
        {
          action = "reboot";
          countdown_seconds = 0.0;
          enabled = true;
          shortcut = "4";
          variant = "default";
        }
        {
          action = "shutdown";
          countdown_seconds = 0.0;
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

  wallaper = {
    enabled = true;
    default.path = "${inputs.nix-assets}/images/wallpapers/astronaut.webp";
  };

  # https://github.com/noctalia-dev/noctalia/issues/3132#issuecomment-4884242113
  lockscreen = {
    enabled = true;
    fingerprint = false; # FIXME: ossa has a builtin fingerprint reader iirc... hostSpec maybe?
    allow_empty_password = true;
  };

  # FIXME: The voxtype stuff should be limited to only specific systems...
  plugins = {
    auto_update = "all";
    enabled = [
      "gabedunn/voxtype"
      "fidgetingbits/voxtype-meeting"
    ];

    # Ordered by load preference
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

  plugin_settings = {
    "gabedunn/voxtype" = {
      show_extended = true;
    };

    "fidgetingbits/voxtype-meeting" = { };
  };

  widget.date.format = "{:%Y.%m.%d}";
}
