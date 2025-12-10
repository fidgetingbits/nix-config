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

  services.awww = {
    enable = true;
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

}
