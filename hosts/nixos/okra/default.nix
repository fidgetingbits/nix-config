# Qemu VM for deployment testing
{
  #inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = lib.flatten [
    #inputs.nixos-facter-modules.nixosModules.facter
    #{ config.facter.reportPath = ./facter.json; }
    ./hardware-configuration.nix
    ./disks.nix
    (map lib.custom.relativeToRoot (
      [
        "hosts/common/core"
        "hosts/common/core/nixos.nix"
      ]
      ++
        # Optional common modules
        (map (f: "hosts/common/optional/${f}") [
          # Host-specific stuff
          "locale.nix"
          "x11.nix"
          "sound.nix"
          "gnome.nix"
          "cli.nix"
          "yubikey.nix"
        ])
    ))
  ];

  hostSpec = {
    hostName = "okra";
    isProduction = lib.mkForce false;
    persistFolder = lib.mkForce "/persist";
  };
  system.impermanence.enable = true;

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
}
