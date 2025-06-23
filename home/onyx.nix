{
  config,
  pkgs,
  ...
}:
{
  imports = [
    common/core
    common/core/nixos.nix

    common/optional/ssh.nix
    common/optional/audio-tools.nix
    common/optional/vscode.nix
    common/optional/development
    common/optional/aws.nix
    common/optional/helper-scripts
    common/optional/sops.nix
    common/optional/xdg.nix
    common/optional/gpg.nix
    common/optional/kitty.nix
    #common/optional/wezterm.nix
    common/optional/gnome-terminal.nix
    common/optional/media.nix
    common/optional/graphics.nix
    common/optional/ebooks.nix
    common/optional/networking/protonvpn.nix
    common/optional/atuin.nix
    common/optional/i3
    common/optional/gnome

    # Maybe more role-specific stuff
    common/optional/document.nix # document editing
    common/optional/gui-utilities.nix # core for any desktop
    common/optional/chat.nix
    common/optional/reversing
    common/optional/wine.nix

  ];

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
