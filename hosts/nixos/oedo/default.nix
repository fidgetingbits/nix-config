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
    inputs.nixos-facter-modules.nixosModules.facter
    { config.facter.reportPath = ./facter.json; }
    (lib.custom.scanPaths ./.) # Load all extra host-specific *.nix files

    (map lib.custom.relativeToRoot (
      [
        ##
        # Core
        ##
        "hosts/common/core"
        "hosts/common/core/nixos.nix"
      ]
      ++ (map (f: "hosts/common/optional/${f}") [
        ##
        # Optional
        ##
        "keyd.nix"

        # Host-specific stuff
        "mail-delivery.nix"
        "plymouth.nix"
        "printing.nix"
        "locale.nix"
        "x11.nix"
        "sound.nix"
        "podman.nix"
        "cli.nix"
        "yubikey.nix"
        "libvirt.nix"

        "wireshark.nix"

        "systemd-resolved.nix"
        # "vpn.nix"

        # Window Manager
        #"gnome.nix"
        "sddm.nix"
        "niri.nix"

        # "binaryninja.nix"
        # "cynthion.nix"
        "saleae.nix"

        # Mounts
        # "mounts/s3fs.nix"

        # Services
        "services/syncthing.nix"
        "services/gns3.nix"

        "remote-builder.nix"
      ])
    ))

  ];

  system.impermanence.enable = true;

  desktops.hyprland.enable = true;

  services.backup = {
    enable = true;
    borgBackupStartTime = "22:00:00";
  };

  # Bootloader.
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

  introdus.system.initrd-wifi = {
    enable = true;
    interface = "wlp193s0";
    drivers = [
      "mt7925e"
    ];
    configFile = lib.custom.relativeToRoot "secrets/wpa_supplicant-olan.conf";
  };

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
    pkgs.introdus.nixos-extract-initrd
  ];

  # FIXME: This could all be automated in a module with hostSpec isWifi and
  # isRoaming and isRemote
  wifi = {
    enable = true;
    wlans = [ "olan" ];
  };

  services.llama.enable = true;

  modules.hardware.radeon.enable = true;
}
