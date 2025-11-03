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
  lib,
  ...
}:
let
  raidDisks = [

    "/dev/disk/by-id/nvme-EDILOCA_EN705_4TB_AA251809669"
    "/dev/disk/by-id/nvme-EDILOCA_EN705_4TB_AA251809987"
    "/dev/disk/by-id/nvme-EDILOCA_EN705_4TB_AA251809895"
    # FIXME: Uncomment after already created, to test adding drive to array
    # after initial install/disko run
    #"/dev/disk/by-id/nvme-EDILOCA_EN705_4TB_AA251809684"
  ];
  primaryDisk = "/dev/disk/by-id/mmc-SCA64G_0x56567305";

  mkRaid =
    level: disks:
    disks
    |> lib.imap0 (
      i: disk: {
        "raidDrive${(toString (i + 1))}" = {
          type = "disk";
          device = disk;
          content = {
            type = "gpt";
            partitions = {
              mdadm = {
                size = "100%";
                content = {
                  type = "mdraid";
                  name = "raid${toString level}";
                };
              };
            };
          };
        };
      }
    )
    |> lib.mergeAttrsList;
in
{
  disko.devices = {
    disk = {
      # EMMC 64GB
      primary = {
        type = "disk";
        device = primaryDisk;
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
    }
    // mkRaid raidDisks;

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
