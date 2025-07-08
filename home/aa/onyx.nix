{
  config,
  pkgs,
  lib,
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
  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # Scaling for HiDPI, specifically for GDM
  # https://discourse.nixos.org/t/need-help-for-nixos-gnome-scaling-settings/24590/5
  # https://github.com/NixOS/nixpkgs/issues/54150
  # home-manager.users.gdm = { lib, ... }: {
  #   dconf.settings = {
  #     "org/gnome/desktop/interface" = {
  #       scaling-factor = lib.hm.gvariant.mkUint32 2;
  #     };
  #   };
  # };
  sops = {
    secrets = {
      "tokens/fly" = {
        path = "${config.hostSpec.home}/.config/fly.io/token";
      };
    };
  };
}
