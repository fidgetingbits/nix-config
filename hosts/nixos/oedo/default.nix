# NOTE: Beelink GR9 BIOS dedicates 96gb to gpu and don't have the option to
# go low and expose everything via GTT like on framework, so just leave it
# dedicated.
#
# See BIOS setting: Advanced -> AMD CBS -> NBIO Common Options -> GFX Configuration
{
  inputs,
  lib,
  config,
  pkgs,
  namespace,
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
        "printing.nix"
        "locale.nix"
        "sound.nix"
        "podman.nix"
        "cli.nix"
        "yubikey.nix"
        # "libvirt.nix"

        "wireshark.nix"

        "systemd-resolved.nix"
        # "vpn.nix"

        # Window Manager
        #"gnome.nix"
        "icons.nix"

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

  services.backup = {
    enable = true;
    borgBackupStartTime = "*-*-* 22:00:00";
  };

  # Bootloader.
  boot.supportedFilesystems = [ "ntfs" ];
  boot.initrd.systemd.enable = true;

  services.remoteLuksUnlock = {
    enable = true;
    notify.to = config.hostSpec.email.olanAdmins;
  };

  introdus = {
    niri.enable = true;
    plymouth.enable = true;
    system.initrd-wifi = {
      enable = true;
      interface = "wlp193s0";
      drivers = [
        "mt7925e"
      ];
      configFile = lib.custom.relativeToRoot "secrets/wpa_supplicant-olan.conf";
    };
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
    subDomains = [ "ogre" ];
  };
  services.fwupd.enable = true;
  environment.systemPackages = [
    pkgs.unstable.lshw
    pkgs.introdus.nixos-extract-initrd
  ];

  # 6.19.6 won't boot, so revert for now
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_6_18;

  # FIXME: This could all be automated in a module with hostSpec isWifi and
  # isRoaming and isRemote
  wifi = {
    enable = true;
    wlans = [ "olan" ];
  };

  ${namespace} = {
    services.llama-swap = {
      enable = true;
      allowedHosts = [
        "ossa"
        "ooze" # Because we don't use NAT for wireguard atm, so roaming ossa will be this
        "opia"
      ];
      # See models set in modules/hosts/nixos/llama-swap.nix for full list
      # Keep default ("all") for now, since everything should run on this box
      # FIXME: We should probably trim stuff that is "weak" and only for Strix Point
      # models = [
      #
      # ];
    };
  };

  boot.kernelParams =
    let
      # 96 GiB dedicated in BIOS
      sz = toString ((96 * 1024 * 1024 * 1024) / 4096);
    in
    [
      "amd_iommu=off" # disables VFIO for local llm speed
      "amdttm.pages_limit=${sz}"
      "amdttm.page_pool_size=${sz}"
      "ttm.pages_limit=${sz}"
      "ttm.page_pool_size=${sz}"
    ];

  modules.hardware.radeon.enable = true;

  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
  };

  services.immichML =
    let
      hosts = config.hostSpec.networking.subnets.olan.hosts;
    in
    {
      enable = true;
      isRemoteMachineLearningServer = true; # Host ML parsing server onlyallowed
      immichServers = [ hosts.ooze ]; # List of systems allowed to access ML service
    };

  # ${namespace}.services.monit = {
  #   enable = true;
  #   usage = {
  #     fileSystem = {
  #       enable = true;
  #       # FIXME:This should be automated from disko subvolume parsing or something
  #       fileSystems = {
  #         rootfs = {
  #           path = "/";
  #         };
  #       };
  #     };
  #   };
  #   health = {
  #     disks = {
  #       enable = true;
  #       smart.disks = map (d: lib.baseNameOf d) [ config.system.disks.primary ];
  #     };
  #     btrfs = {
  #       enable = true;
  #       inherit (config.services.btrfs.autoScrub) fileSystems;
  #     };
  #   };
  # };
}
