# mdadm and raid5 reference:
# https://github.com/mitchty/nix/blob/shenanigans/nix/nixosConfigurations/gw0/diskconfig.nix

# NOTE this will automatically trigger a resync, which can impact nixos-anywhere's ability to
# reboot. You can see with systemd-inhibit that udiskd is running an operation
# See the progress with cat /proc/mdstat (takes about 2 hours with 6TB)
# You can stop the resync by using the following:

# ```
# echo frozen > /sys/block/md0/md/sync_action
# echo none > /sys/block/md0/md/resync_start
# echo idle > /sys/block/md0/md/sync_action
# ```
# See https://serverfault.com/questions/216508/how-to-interrupt-software-raid-resync
{
  config,
  ...
}:
let
  raidDisks = [
    "/dev/disk/by-id/nvme-CT2000P3PSSD8_2504E9A1BF6E"
    "/dev/disk/by-id/nvme-CT2000P3PSSD8_2504E9A1BF62"
    "/dev/disk/by-id/nvme-CT2000P3PSSD8_2504E9A1BF79"
  ];
in
{

  # FIXME: To delete, this should be fixed in 24.05 actually
  # https://github.com/NixOS/nixpkgs/issues/72394
  #boot.swraid.mdadmConf = "PROGRAM ${pkgs.coreutils}/bin/true";

  disko.devices = {
    disk = {
      # EMMC 64GB
      primary = {
        type = "disk";
        #device = "/dev/mmcblk0"; # 64GB
        device = "/dev/disk/by-id/mmc-DV4064_0x6101b932";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "defaults" ];
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "encrypted-nixos";
                passwordFile = "/tmp/disko-password"; # populated by bootstrap-nixos.sh
                settings = {
                  allowDiscards = true;
                };
                # Subvolumes must set a mountpoint in order to be mounted,
                # unless their parent is mounted
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ]; # force overwrite
                  subvolumes = {
                    "@root" = {
                      mountpoint = "/";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                    "@persist" = {
                      mountpoint = "${config.hostSpec.persistFolder}";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                    "@nix" = {
                      mountpoint = "/nix";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                    "@swap" = {
                      mountpoint = "/.swapvol";
                      # 2G is somewhat arbitrary, but EMMC is small and we shouldn't need much
                      swap.swapfile.size = "2G";
                    };
                  };
                };
              };
            };
          };
        };
      };

      # FIXME: Use a mkRaidDisk func?
      # RAID5 three 2TB drives
      # Disk 1
      d1 = {
        type = "disk";
        device = builtins.elemAt raidDisks 0;
        content = {
          type = "gpt";
          partitions = {
            mdadm = {
              size = "100%";
              content = {
                type = "mdraid";
                name = "raid5";
              };
            };
          };
        };
      };

      # Disk 2
      d2 = {
        type = "disk";
        device = builtins.elemAt raidDisks 1;
        content = {
          type = "gpt";
          partitions = {
            mdadm = {
              size = "100%";
              content = {
                type = "mdraid";
                name = "raid5";
              };
            };
          };
        };
      };

      # Disk 3
      d3 = {
        type = "disk";
        device = builtins.elemAt raidDisks 2;
        content = {
          type = "gpt";
          partitions = {
            mdadm = {
              size = "100%";
              content = {
                type = "mdraid";
                name = "raid5";
              };
            };
          };
        };
      };
    };

    mdadm = {
      raid5 = {
        type = "mdadm";
        level = 5;
        content = {
          type = "luks";
          name = "encrypted-storage";
          passwordFile = "/tmp/disko-password";
          settings = {
            allowDiscards = true;
          };
          # Whether to add a boot.initrd.luks.devices entry for this disk.
          # We only want to unlock cryptroot interactively.
          # You must have a /etc/crypttab entry set up to auto unlock the drive using a key on cryptroot
          # (see ./default.nix)
          initrdUnlock = if config.hostSpec.isMinimal then true else false;

          content = {
            type = "btrfs";
            extraArgs = [ "-f" ]; # force overwrite
            subvolumes = {
              "@storage" = {
                mountpoint = "/mnt/storage";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
              };
            };
          };
        };
      };
    };
  };
}
