{
  pkgs,
  lib,
  ...
}:
{
  imports = (
    map lib.custom.relativeToRoot (
      # FIXME: remove after fixing user/home values in HM
      [
        "home/common/core"
        "home/common/core/nixos.nix"
      ]
      ++
        # Optional common modules
        (map (f: "home/common/optional/${f}") [
          "sops.nix"
          "ssh/"

          "audio-tools.nix"
          "development"
          "helper-scripts"
          "xdg.nix"
          "gpg.nix"
          #"kitty.nix"
          #"wezterm.nix"
          "ghostty.nix"
          "media.nix"
          "networking/protonvpn.nix"
          "atuin.nix"

          "desktop/gnome"
          "gnome-terminal.nix"
          "fcitx5"

          # Maybe more role-specific stuff
          "document.nix" # document editing
          "gui-utilities.nix" # core for any desktop
        ])
    )
  );

  home.packages = builtins.attrValues {
    inherit (pkgs)
      openrgb-with-all-plugins # for controlling RGB devices
      ffmpeg # mp4 -> gif conversion, etc
      amdgpu_top # AMD GPU monitoring
      ;
  };

  services.yubikey-touch-detector.enable = true;
  services.yubikey-touch-detector.notificationSound = true;

  # FIXME: Make this gnome-specific
  dconf.settings = {
    "org/gnome/settings-daemon/plugins/power" = {
      power-button-action = lib.mkForce "suspend";
    };
  };
}
