# model
{
  inputs,
  lib,
  pkgs,
  config,
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
        "hosts/common/core"
        "hosts/common/core/nixos.nix"
      ]
      ++
        # Optional common modules
        (map (f: "hosts/common/optional/${f}") [
          # Network management
          "systemd-resolved.nix"

          # Misc
          "mail-delivery.nix"
          "logind.nix"
          "cli.nix"
        ])
    ))
  ];

  system.impermanence.enable = true;
  services.dyndns.enable = true;

  environment.systemPackages = [ pkgs.borgbackup ];

  services.remoteLuksUnlock = {
    enable = true;
    notify.to = config.hostSpec.email.${config.hostSpec.hostName}.alerts;
    ssh.users = [
      "aa"
      "ta"
    ];
  };

  # Override the physical key to reboot on short press
  services.logind.settings.Login.HandlePowerKey = lib.mkForce "reboot";

  # Setup NUT server and corresponding client for USB-attached UPS device
  services.ups = {
    server.enable = true;
    username = "nut";
    name = "cyberpower";
    powerDownTimeOut = (2 * 60); # 2m. UPS reports ~10min
  };
  power.ups.ups.cyberpower = {
    driver = "usbhid-ups";
    description = "CyberPower CP1500PFCLCDa";
    port = "auto";
    directives = [
      "vendorid = 0764"
      "productid = 0601"
    ];
  };
  systemd = {
    tmpfiles.rules =
      let
        name = user: config.users.users.${user}.name;
        group = user: config.users.users.${user}.group;
      in
      [
        "d /mnt/storage/backup/ 2770 ${name "borg"} ${group "borg"} -"
        "d /mnt/storage/mirror/ 2770 ${name "borg"} ${group "borg"} -"
        # Because we mirror from oath, which doesn't already use aa/ prefix for copying
        "d /mnt/storage/mirror/aa 2770 ${name "borg"} ${group "borg"} -"
      ]
      # In some cases borg user is used to backup to these folders, so needs users access
      ++ (lib.map (u: "d /mnt/storage/backup/${u} 0770 ${name "${u}"} ${group "${u}"} -") [
        "aa"
        "ta"
      ]);
  };
  systemd.services.systemd-tmpfiles-setup = {
    after = [ "mnt-storage.mount" ];
    requires = [ "mnt-storage.mount" ];
  };

  services.mirror-backups = {
    enable = true;
    notify.to = config.hostSpec.email.${config.hostSpec.hostName}.backups;
    time = "*-*-* 5:00:00"; # Keep sync with myth times
    server = "myth.${config.hostSpec.domain}";
  };

  # Allow other servers to mirror their backups into moth
  users.users.borg.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICMso7GIZT7pDRxeE8xd+hkwUySI8v8LwvDn1gPJyGFK myth"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOLLKlQQu/pl8e/Vs3c60crZqjwhB/GV3C58EmTD/L1y onyx"
  ];

  services.backup = {
    enable = true;
    borgBackupStartTime = "09:00:00";
    borgServer = "myth.${config.hostSpec.domain}";
    borgRemotePath = "/run/current-system/sw/bin/borg";
    borgBackupPath = "/mnt/storage/backup/aa";
    borgNotifyTo = config.hostSpec.email.${config.hostSpec.hostName}.backups;
  };

  # Try to avoid bluez package
  hardware.bluetooth.enable = lib.mkForce false;

  # FIXME: Have a btrfs.nix file auto-load of the disks config contains btrfs filesystems, and if so
  # automatically populate the paths for monit as well
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly"; # Because of this raid uses nvme's
    fileSystems = [
      "/"
      "/mnt/storage"
    ];
  };

  ${namespace}.services.monit = {
    enable = true;
    usage = {
      fileSystem = {
        enable = true;
        fileSystems = {
          rootfs = {
            path = "/";
          };
          storage = {
            path = "/mnt/storage";
          };
        };
      };
    };
    health = {
      disks = {
        enable = true;
        smart.disks = map (d: builtins.baseNameOf d) config.system.disks.raidDisks;
        emmc.disks = {
          "mmc-SCA64G_0x56567305" = { };
        };
      };
      mdadm = {
        enable = true;
        disks = [ "md127" ];
      };
      btrfs = {
        enable = true;
        inherit (config.services.btrfs.autoScrub) fileSystems;
      };
    };
  };
}
