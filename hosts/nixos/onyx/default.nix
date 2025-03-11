# Asus Zenbook Flip S13 UX371E
{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:
{
  imports = lib.flatten [
    inputs.nixos-hardware.nixosModules.asus-zenbook-ux371
    ./hardware-configuration.nix

    (map lib.custom.relativeToRoot [
      "hosts/common/core"
      "hosts/common/core/nixos.nix"

      # Host-specific stuff
      "hosts/common/optional/msmtp.nix"
      "hosts/common/optional/plymouth.nix"
      "hosts/common/optional/printing.nix"
      "hosts/common/optional/locale.nix"
      "hosts/common/optional/x11.nix"
      "hosts/common/optional/sound.nix"

      # Desktop environment and login manager
      "hosts/common/optional/display-manager.nix"
      "hosts/common/optional/gnome.nix"
      "hosts/common/optional/i3wm.nix"

      "hosts/common/optional/podman.nix"
      "hosts/common/optional/libvirt.nix"
      "hosts/common/optional/wireshark.nix"
      "hosts/common/optional/cli.nix"
      "hosts/common/optional/yubikey.nix"
      "hosts/common/optional/tobii.nix"
      "hosts/common/optional/services/openssh.nix"
      "hosts/common/optional/iphone-backup.nix"

      "hosts/common/optional/binaryninja.nix"
      "hosts/common/optional/cynthion.nix"
      "hosts/common/optional/saleae.nix"

      # Network management
      "hosts/common/optional/systemd-resolved.nix"

      # Remote network mounts and syncing
      "hosts/common/optional/mounts/oath-cifs.nix"
      "hosts/common/optional/mounts/onus-cifs.nix"
      "hosts/common/optional/services/syncthing.nix"

      # Gaming
      "hosts/common/optional/gaming.nix"
    ])
  ];

  # Host Specification
  hostSpec = {
    hostName = "onyx";
    isWork = lib.mkForce true;
    voiceCoding = lib.mkForce true;
    useYubikey = lib.mkForce true;
    isAutoStyled = lib.mkForce true;
    wifi = lib.mkForce true;
    useNeovimTerminal = lib.mkForce true;
    hdr = lib.mkForce true;
    scaling = lib.mkForce "2";
    isProduction = lib.mkForce true;
    #useAtticCache = lib.mkForce false;
    isDevelopment = lib.mkForce true;

  };

  boot.kernelPackages = pkgs.linuxPackages_latest;
  # Bootloader.
  boot.loader.systemd-boot = {
    enable = true;
    # When using plymouth, initrd can expand by a lot each time, so limit how many we keep around
    configurationLimit = lib.mkDefault 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # Just set the console font, don't mess with the font settings
  #console.font = lib.mkDefault "${pkgs.terminus_font}/share/consolefonts/ter-v32n.psf.gz";
  console.earlySetup = lib.mkDefault true;

  # Setup keyfile
  boot.initrd.secrets = {
    "/crypto_keyfile.bin" = null;
  };

  # Enable swap on luks
  boot.initrd.luks.devices."luks-e2232963-327f-4833-9bcc-5e5a8dae9551".device =
    "/dev/disk/by-uuid/e2232963-327f-4833-9bcc-5e5a8dae9551";
  boot.initrd.luks.devices."luks-e2232963-327f-4833-9bcc-5e5a8dae9551".keyFile =
    "/crypto_keyfile.bin";
  boot.initrd.systemd.enable = true;
  boot.supportedFilesystems = [ "ntfs" ];

  # We need IPv6 in order to access hetzner cloud systems
  networking.networkmanager.enable = true;
  networking.useDHCP = lib.mkDefault true;
  #networking.enableIPv6 = true;

  # Keyring, required for auth even without gnome
  security.pam.services.sddm.enableGnomeKeyring = true;

  environment.systemPackages = builtins.attrValues {
    inherit (pkgs)
      # Access iphone data
      ifuse
      libimobiledevice

      # gnupg - see yubikey.nix
      paperkey # printed gpg key backup utilitie
      pinentry-curses # for gpg-agent
      pinentry-gtk2 # for gpg-agent
      ;
  };
  services.fwupd.enable = true;
  voiceCoding.enable = true;
  services.backup = {
    enable = true;
    borgBackupStartTime = "09:00:00";
    # This is only relevant while I'm not using btrfs subvolume backup
    borgExcludes = [ "${config.hostSpec.home}/movies" ];
  };

  services.per-network-services =
    let
      # Define what trusted networks looks like for this system
      oryx = {
        type = "wireless";
        ssid = "oryx";
        interface = "wlo1";
        gateway = inputs.nix-secrets.networking.subnets.ogre.hosts.oryx.ip;
        mac = inputs.nix-secrets.networking.subnets.ogre.hosts.oryx.mac;
      };
      ogre = {
        type = "wired";
        domain = inputs.nix-secrets.domain;
        interface = "";
        gateway = inputs.nix-secrets.networking.subnets.ogre.hosts.ogre.ip;
        mac = inputs.nix-secrets.networking.subnets.ogre.hosts.ogre.mac;
      };
    in
    {
      enable = true;
      debug = true; # FIXME(onyx): Remove this
      # FIXME: This should be synchronized with the code that renames it
      networkDevices = [ "wlo1" ];
      trustedNetworks = [
        oryx
        ogre
      ];
    };
  networking.granularFirewall.enable = true;

  system.stateVersion = "23.05";
}
