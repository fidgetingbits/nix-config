{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = (
    map lib.custom.relativeToRoot (
      [
        "home/common/core"
        "home/common/core/nixos.nix"
      ]
      ++
        # Optional common modules
        (map (f: "home/common/optional/${f}") [
          "audio-tools.nix"
          # "vscode"
          "xdg.nix"
          "helper-scripts"
          "development"
          "aws.nix"
          "gpg.nix"
          "sops.nix"
          "media.nix"

          "graphics.nix"

          "atuin.nix"

          "remmina.nix"

          "chat.nix"
          "work.nix"

          "reversing"

          "wine.nix"

          #"wezterm.nix"
          #"kitty.nix"
          "ghostty.nix"

          # Tied to an enable probably

          "desktop/gnome"
          "gnome-terminal.nix"

          # These should be linked together somehow
          "desktop/wayland"
          "desktop/hyprland"
          "desktop/kanshi.nix"
          "desktop/waybar.nix"
        ])
    )
  );

  home.packages = lib.attrValues {
    inherit (pkgs)
      cyberpower-pdu
      easylkb
      slideshare-downloader
      burpsuite
      ;
  };

  services.swww = {
    enable = true;
    # FIXME: Setup a dualup specific folder
    wallpaperDir = "${config.home.homeDirectory}/images/walls-catppuccin-mocha";
  };

  services.yubikey-touch-detector.enable = true;
  services.yubikey-touch-detector.notificationSound = true;
  services.snixembed.enable = config.hostSpec.voiceCoding;
  system.ssh-motd.enable = true;
  settings.work.enable = config.hostSpec.isWork;

  # talon = {
  #   enable = true;
  #   autostart = lib.mkForce true;
  # };

  sops = {
    secrets = {
      # for systems that don't support yubikey
      "keys/ssh/ed25519" = {
        path = "${config.home.homeDirectory}/.ssh/id_ed25519";
      };
    };
  };

  home.file = {
    ".ssh/id_ed25519.pub".source = lib.custom.relativeToRoot "hosts/nixos/oedo/keys/id_ed25519.pub";
  };

  #
  # ========== Host-specific Monitor Spec ==========
  #
  # This uses the nix-config/modules/home/monitors.nix module
  # Your nix-config/home/<user>/common/optional/desktops/foo.nix WM config should parse and apply these values to it's monitor settings
  # If on hyprland, use `hyprctl monitors` to get monitor info.
  # https://wiki.hyprland.org/Configuring/Monitors/
  #           --------      --------
  #         | HDMI-A-1 |  | HDMI-B-1 |
  #           --------      --------
  monitors = [
    {
      name = "HDMI-A-1";
      width = 2560;
      height = 2880;
      refreshRate = 120;
      #transform = 2;
      scale = 1;
    }
    # FIXME: Need to switch the offset?
    {
      name = "HDMI-B-1";
      width = 2560;
      height = 2880;
      refreshRate = 120;
      #transform = 2;
      scale = 1;
    }

  ];
}
