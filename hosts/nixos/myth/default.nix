# Beelink EQR5
# NOTE: All .nix files in ./ are auto-loaded, so look there for extra logic
{
  inputs,
  lib,
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
          "logind.nix"
          "cli.nix"
        ])
    ))
  ];

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

  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly"; # This raid uses nvme's
    # Defaults to all filesystems
  };

  # Connect our NUT client to the UPS on the network
  services.ups = {
    client.enable = true;
    name = "ups";
    username = "monuser";
    ip = config.hostSpec.networking.subnets.${config.hostSpec.hostName}.hosts.synology.ip;
    powerDownTimeOut = (60 * 30); # 30m. UPS reports ~45min
  };

  ${namespace}.services.monit = {
    enable = true;
    usage = {
      fileSystem = {
        enable = true;
        # FIXME:This should be automated from disko subvolume parsing or something
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
        smart.disks = map (d: lib.baseNameOf d) config.system.disks.raidDisks;
        emmc = {
          enable = true;
          disks = {
            "mmc-DV4064_0x6101b932" = { };
          };
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
