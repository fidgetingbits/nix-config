{ pkgs, lib, ... }:
{
  imports = lib.custom.scanPaths ./.;
  # Probably move this eventually
  # see Martins3/My-Linux-Config and rxyhn/yuki for more
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
  };

  home.packages =
    builtins.attrValues {
      inherit (pkgs)
        chrome-gnome-shell # Allow gnome extension installation from chrome
        # FIXME: See if we can get settings described here https://itsfoss.com/three-finger-swipe-gnome/ declaratively
        # https://discourse.nixos.org/t/need-help-for-nixos-gnome-scaling-settings/24590/5
        #touchegg # touchpad gestures
        gnome-tweaks
        simple-scan
        ;
    }
    ++ [
      pkgs.gnomeExtensions.x11-gestures
      (pkgs.chromium.override { enableWideVine = true; }) # to allow gui-based extension management
    ];
}
