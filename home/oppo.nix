{
  ...
}:
{
  imports = [
    common/core
    common/core/nixos.nix

    common/optional/sops.nix
    common/optional/ssh.nix

    common/optional/audio-tools.nix
    #ommon/optional/vscode.nix
    common/optional/development
    common/optional/helper-scripts
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
    common/optional/gnome

    # Maybe more role-specific stuff
    common/optional/document.nix # document editing
    common/optional/gui-utilities.nix # core for any desktop
  ];

  home.packages = builtins.attrValues {

  };

  services.yubikey-touch-detector.enable = true;
  services.yubikey-touch-detector.notificationSound = true;
  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

}
