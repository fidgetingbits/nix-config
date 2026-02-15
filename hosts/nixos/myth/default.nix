# Beelink EQR5
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

  environment.systemPackages = [ pkgs.borgbackup ];

  # wlo1 boot delay
  #
  # FIXME: I removed wlo1 entirely from facter.json since the below didn't work,
  # but leaving it in. See facter.json.wlo1.bk for old version (or regenerate).
  #
  # Add neededForBoot = false to stop the 1m30s wait on startup once
  # https://github.com/NixOS/nixpkgs/pull/360092 is finalized
  #
  # None of these work to stop the 1m30s delay on boot, but leaving for reference
  # boot.blacklistedKernelModules = [
  #   "iwlwifi"
  # ];
  # networking.interfaces.wlo1.useDHCP = false;
  # systemd.network.netdevs.wlo1.enable = false;

  services.remoteLuksUnlock = {
    enable = true;
    notify.to = config.hostSpec.email.${config.hostSpec.hostName}.alerts;
    ssh.users = [
      "aa"
      "ta"
    ];
  };
  services.logind.settings.Login.HandlePowerKey = lib.mkForce "reboot";
  services.dyndns.enable = true;

  # FIXME:This should be duplcated between myth/moth probably
  systemd = {
    tmpfiles.rules =
      let
        name = user: config.users.users.${user}.name;
        group = user: config.users.users.${user}.group;
      in
      [
        "d /mnt/storage/backup/ 2770 ${name "borg"} ${group "borg"} -"
        "d /mnt/storage/mirror/ 2770 ${name "borg"} ${group "borg"} -"
        "d /mnt/storage/share/ 2770 ${name "aa"} ${group "aa"} -"
      ]
      ++ (lib.map (u: "d /mnt/storage/backup/${u} 0770 ${name "${u}"} ${group "${u}"} -") [
        "pa"
        "aa"
      ]);
  };

  services.mirror-backups = {
    enable = true;
    time = "*-*-* 4:00:00"; # Keep sync with moth times
    server = "moth.${config.hostSpec.domain}";
    notify.to = config.hostSpec.email.${config.hostSpec.hostName}.backups;
  };

  # Allow moth to mirror into myth
  users.users.borg.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKZp+oB8eZjz/S5Q8T8uFfq2yCt5NQWI3/Mm6q+ToAsA root@moth"
  ];

  services.backup = {
    enable = true;
    borgBackupStartTime = "04:30:00";

    borgServer = "moth.${config.hostSpec.domain}";
    borgRemotePath = "/run/current-system/sw/bin/borg";
    borgBackupPath = "/mnt/storage/backup/aa";
    borgNotifyTo = config.hostSpec.email.${config.hostSpec.hostName}.backups;
  };

  # Connect our NUT client to the UPS on the network
  services.ups = {
    client.enable = true;
    name = "ups";
    username = "monuser";
    ip = config.hostSpec.networking.subnets.${config.hostSpec.hostName}.hosts.synology.ip;
    powerDownTimeOut = (60 * 30); # 30m. UPS reports ~45min
  };

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
      disk = {
        enable = true;
        disks = [
          "mmcblk0"
          "nvme0n1"
          "nvme1n1"
          "nvme2n1"
        ];
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
