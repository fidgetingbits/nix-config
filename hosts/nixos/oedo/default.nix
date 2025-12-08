# Dell Precision 5570
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = lib.flatten [
    (map lib.custom.relativeToRoot (
      [
        ##
        # Core
        ##
        "hosts/common/core"
        "hosts/common/core/nixos.nix"
      ]
      ++
        # Optional common modules
        (map (f: "hosts/common/optional/${f}") [
          ##
          # Optional
          ##
          "keyd.nix"

          # Host-specific stuff
          "mail.nix"
          "plymouth.nix"
          "printing.nix"
          "locale.nix"
          "x11.nix"
          "sound.nix"
          "podman.nix"
          "cli.nix"
          "yubikey.nix"
          "tobii.nix"
          "libvirt.nix"

          "wireshark.nix"

          "systemd-resolved.nix"
          # "vpn.nix"

          # Window Manager
          #"gnome.nix"
          "sddm.nix"

          "binaryninja.nix"
          # "cynthion.nix"
          "saleae.nix"

          # Services
          "mounts/oath-cifs.nix"
          "mounts/onus-cifs.nix"

          # "mounts/s3fs.nix"
          "services/openssh.nix"
          "services/syncthing.nix"
          "services/gns3.nix"

          "remote-builder.nix"
        ])
    ))

    inputs.nixos-facter-modules.nixosModules.facter
    { config.facter.reportPath = ./facter.json; }
    ./disks.nix
    ./network.nix
    # lanzaboote
    #./secureboot.nix
  ];

  hostSpec = {
    hostName = "oedo";
    isWork = lib.mkForce false;
    voiceCoding = lib.mkForce false;
    useYubikey = lib.mkForce true;
    wifi = lib.mkForce true;
    useNeovimTerminal = lib.mkForce false;
    persistFolder = lib.mkForce "/persist";
    isProduction = lib.mkForce true;
    isAutoStyled = lib.mkForce true;
    isDevelopment = lib.mkForce true;
    isAdmin = lib.mkForce true;

    # FIXME: We should have like "desktop" = "hyprland" and have that auto enable the rest?
    defaultDesktop = "hyprland-uwsm";
    useWayland = true;
  };
  system.impermanence.enable = true;

  desktops.hyprland.enable = true;
  voiceCoding.enable = config.hostSpec.voiceCoding;

  # FIXME: Re-enable after pinning the most recent after device switch
  # services.backup = {
  #   enable = true;
  #   borgBackupStartTime = "22:00:00";
  # };

  # Bootloader.
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = lib.mkDefault 8;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "ntfs" ];
  boot.initrd.systemd.enable = true;

  # FIXME: This should move to somewhere generic
  systemd.tmpfiles.rules = [
    "d    /home/${config.hostSpec.username}/mount    0700    ${config.hostSpec.username}    users    -    -"
  ];

  services.remoteLuksUnlock = {
    enable = true;
    notify.to = config.hostSpec.email.olanAdmins;
  };

  system.initrd-wifi = {
    enable = true;
    interface = "wlp193s0";
    drivers = [
      "mt7925e"
    ];
    configFile = lib.custom.relativeToRoot "secrets/wpa_supplicant-olan.conf";
  };

  # Stop blocking on network interfaces not needed for boot
  systemd.network.wait-online.enable = false;
  services.gnome.gnome-keyring.enable = true;

  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false;
  # FIXME:double check this
  networking.dhcpcd.wait = "background";

  # ooze checks for all other hosts, so we just check ooze
  services.heartbeat-check = {
    enable = true;
    interval = 10 * 60;
    hosts = [ "ooze" ];
  };
  # Redundancy in case ooze goes down
  services.dyndns = {
    enable = true;
    subDomain = "ogre";
  };
  services.fwupd.enable = true;
  environment.systemPackages = [
    pkgs.unstable.lshw
    pkgs.nixos-extract-initrd
  ];

  # FIXME: This could all be automated in a module with hostSpec isWifi and
  # isRoaming and isRemote
  wifi = {
    enable = true;
    wlans = [ "olan" ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = "23.05";
}
