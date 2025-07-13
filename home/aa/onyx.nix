{
  config,
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
          "ssh.nix"
          "audio-tools.nix"
          "vscode.nix"
          "development"
          "aws.nix"
          "helper-scripts"
          "sops.nix"
          "xdg.nix"
          "gpg.nix"
          #common/optional/kitty.nix
          "ghostty.nix"
          #common/optional/wezterm.nix
          "gnome-terminal.nix"
          "media.nix"
          "graphics.nix"
          "ebooks.nix"
          "networking/protonvpn.nix"
          "atuin.nix"
          "i3"
          "gnome"
          "fcitx5"

          # Maybe more role-specific stuff
          "document.nix" # document editing
          "gui-utilities.nix" # core for any desktop
          "chat.nix"
          "reversing"
          "wine.nix"
          "llm.nix"
        ])
    )
  );

  talon = {
    enable = false;
    autostart = false;
    pynvim = true;
    #  gaze-ocr = true;
  };

  home.packages = builtins.attrValues {
    inherit (pkgs)
      cyberpower-pdu
      easylkb
      ntfs3g
      ;
  };

  # Allows to show talon icon in system tray
  services.snixembed.enable = true;
  services.yubikey-touch-detector.enable = true;
  services.yubikey-touch-detector.notificationSound = true;

  sops = {
    secrets = {
      "tokens/fly" = {
        path = "${config.home.homeDirectory}/.config/fly.io/token";
      };
    };
  };
}
