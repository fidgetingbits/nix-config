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
          "gnome-terminal.nix"

          "wezterm.nix"
          "kitty.nix"
          "graphics.nix"

          "atuin.nix"

          "remmina.nix"

          "chat.nix"
          "work.nix"
          "desktop/gnome"

          "reversing"

          "wine.nix"

          # "i3"
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
