{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = lib.custom.scanPaths ./.;
  # Probably move this eventually
  # see Martins3/My-Linux-Config and rxyhn/yuki for more
  # dconf2nix seems neat: https://github.com/Sly-Harvey/NixOS/blob/1acf7d8f3b785f7643f5601695a7f79a5bf9c261/modules/desktop/gnome/dconf.nix
  dconf.settings = {
    "org/gnome/shell" = {
      disable-user-extensions = false;
      disable-extension-version-validation = true;
    };
    "org/gnome/settings-daemon/plugins/power" = {
      ambient-enabled = false;
      idle-dim = true;
      power-button-action = "interactive";
      sleep-inactive-ac-type = "nothing";
      sleep-inactive-ac-timeout = 0;
      sleep-inactive-battery-type = "nothing";
      sleep-inactive-battery-timeout = 0;
    };
    "org/gnome/desktop/wm/preferences" = {
      num-workspaces = 8;
    };
    "org/gnome/mutter" = {
      dynamic-workspaces = false;
    };
    "org/gnome/desktop/interface" = {
      enable-hot-corners = false;
    };
    "org/gnome/desktop/privacy" = {
      report-technical-problems = "false";
    };
    "org/gnome/desktop/peripherals/mouse" = {
      left-handed = false;
      speed = 2;
      accel-profile = "default";
      natural-scroll = false;
    };
    # FIXME: Not sure how this works if monitors differ
    "org/gnome/desktop/interface" = {
      scaling-factor = lib.hm.gvariant.mkUint32 config.hostSpec.scaling;
    };
  };

  home.packages =
    builtins.attrValues {
      inherit (pkgs)
        chromium
        gnome-browser-connector # Allow gnome extension installation from chrome
        # FIXME: See if we can get settings described here https://itsfoss.com/three-finger-swipe-gnome/ declaratively
        # https://discourse.nixos.org/t/need-help-for-nixos-gnome-scaling-settings/24590/5
        #touchegg # touchpad gestures
        gnome-tweaks
        simple-scan
        ;
    }
    ++ [
      pkgs.gnomeExtensions.x11-gestures
      pkgs.gnomeExtensions.appindicator
      pkgs.gnomeExtensions.dash-to-dock # Allow you to permanently show the dash (icon bar)
      #(pkgs.chromium.override { enableWideVine = true; }) # to allow gui-based extension management
    ];
}
