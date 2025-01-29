# Qemu VM for deployment testing
{
  lib,
  pkgs,
  ...
}:
{
  imports = lib.flatten [
    # Every host needs this
    ./hardware-configuration.nix
    # disk layout

    (lib.custom.relativeToRoot "hosts/common/disks/btrfs-luks-impermanence-disko.nix")
    {
      _module.args = {
        disk = "/dev/vda";
        withSwap = false;
      };
    }
    (map lib.custom.relativeToRoot [

      "hosts/common/core"
      "hosts/common/core/nixos.nix"

      # Host-specific stuff
      "hosts/common/optional/locale.nix"
      "hosts/common/optional/x11.nix"
      "hosts/common/optional/sound.nix"
      "hosts/common/optional/gnome.nix"
      "hosts/common/optional/cli.nix"
      "hosts/common/optional/yubikey.nix"
      "hosts/common/optional/services/openssh.nix"
    ])
  ];

  hostSpec = {
    hostName = "okra";
    isProduction = lib.mkForce false;
    persistFolder = lib.mkForce "/persist";
  };
  system.impermanence.enable = true;

  boot.loader.systemd-boot = {
    enable = true;
    # When using plymouth, initrd can expand by a lot each time, so limit how many we keep around
    configurationLimit = lib.mkDefault 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd = {
    systemd.enable = true;
    # FIXME: Not sure we need to be explicit with all, but testing virtio due to luks disk errors on qemu
    # This mostly mirrors what is generated on qemu from nixos-generate-config in hardware-configuration.nix
    # NOTE: May be important here for this to be kernelModules, not just availableKernelModules
    kernelModules = [
      "xhci_pci"
      "ohci_pci"
      "ehci_pci"
      "virtio_pci"
      # "virtio_scsci"
      "ahci"
      "usbhid"
      "sr_mod"
      "virtio_blk"
    ];
  };

  # We need IPv6 in order to access hetzner cloud
  #networking.networkmanager.enable = true;
  networking.enableIPv6 = true;

  # Keyring, required for auth even without gnome
  # This is used by VSCode, so we want it to be enabled
  services.gnome.gnome-keyring.enable = true;
  # Automatically try to unlock gnome-keyring on login
  security.pam.services.gdm.enableGnomeKeyring = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  environment.systemPackages = lib.attrValues {
    inherit (pkgs)
      # editing
      xclip # required for clipboard with vim

      # window management
      snixembed # Old school system tray (talon icon, etc)

      # ricing
      plymouth # bootscreen
      adi1090x-plymouth-themes # https://github.com/adi1090x/plymouth-themes

      # gnupg - see yubikey.nix
      paperkey # printed gpg key backup utilitie
      pinentry-curses # for gpg-agent
      pinentry-gtk2 # for gpg-agent
      ;
  };

  system.stateVersion = "23.05";
}
