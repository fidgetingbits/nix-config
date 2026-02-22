# Options for setting up disks with disko. This is very opinionated and just
# made to avoid duplication across systems using similar btrfs partitions and
# settings across hosts

# mdadm and raid5 reference:
# https://github.com/mitchty/nix/blob/shenanigans/nix/nixosConfigurations/gw0/diskconfig.nix
#
# NOTE use of mdadm and raid5 will automatically trigger a resync during
# initial installation, which can impact nixos-anywhere's ability to reboot.
# You can see with systemd-inhibit that udiskd is running an operation. See the
# progress with cat /proc/mdstat (takes about 2 hours with 6TB) You can stop
# the resync by using the following:

# ```
# echo frozen > /sys/block/md0/md/sync_action
# echo none > /sys/block/md0/md/resync_start
# echo idle > /sys/block/md0/md/sync_action
# ```
# See https://serverfault.com/questions/216508/how-to-interrupt-software-raid-resync

{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.system.disks;
in
{
  imports = [
    inputs.disko.nixosModules.disko
  ];
  options = {
    system.disks = {
      # NOTE: Enabled by default
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Use disko templates to manage disks";
      };
      primary = lib.mkOption {
        type = lib.types.str;
        example = "/dev/disk/by-id/mmc-SCA64G_0x56567305";
        description = "Primary install disk";
      };
      primaryDiskoLabel = lib.mkOption {
        type = lib.types.str;
        default = "primary";
        example = "primary";
        description = ''
          Label of primary drive defined in disko.device.disk.
          Only useful if you already had a different label defined and \
          are switching to this module or want a specific disk label in \
          /dev/disk/by-partlabel/ other than disk-primary-{root,luks}. \
          View with 'lsblk -o NAME,PARTLABEL,LABEL,FSTYPE,MOUNTPOINT'
        '';
      };
      luks = {
        enable = lib.mkEnableOption "Use LUKs on primary and raid drives";
        label = lib.mkOption {
          type = lib.types.str;
          example = "encrypted-nixos";
          description = "Label of primary luks partition";
          default = "encrypted-nixos";
        };
      };
      swapSize = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        example = "2G";
        description = "Size of swap drive or null for no swap";
        default = null;
      };
      bootSize = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        example = "512M";
        description = "Size of /boot partition. Bigger allows more boot entries";
        default = "512M";
      };
      raidLevel = lib.mkOption {
        type = lib.types.int;
        example = 5;
        default = 5;
        description = "Type of raid to use with mdadm";
      };
      raidDisks = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        example = [
          "/dev/disk/by-id/nvme-EDILOCA_EN705_4TB_AA251809669"
          "/dev/disk/by-id/nvme-EDILOCA_EN705_4TB_AA251809987"
        ];
        description = "List of drives to add to mdadm raid array. Raid disabled if not set";
      };
      extraDisks = lib.mkOption {
        type = lib.types.listOf (lib.types.attrsOf lib.types.str);
        default = [
          {
            name = "encrypted-storage";
            # FIXME: Should check how to control the name-any-raid5 parts in disko
            path = "/dev/disks/by-id/md-name-any:raid5";
          }
        ];
        description = "Names and labels of non-primary luks-encrypted disks, used for automatic boot-time LUKS unlocking.";
        example = [
          {
            name = "encrypted-storage";
            path = "/dev/disks/by-id/md-name-any:raid5";
          }
        ];
      };
      raidMountPath = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/storage";
        description = "Path to mount the RAID array";
        example = "/mnt/storage";
      };
    };
  };

  config =
    let
      hasRaid = cfg.raidDisks != null;

      # Base luks volume that will contains btrfs sub-content
      luksContent = {
        type = "luks";
        name = config.system.disks.luks.label;
        passwordFile = "/tmp/disko-password"; # populated by bootstrap-nixos
        settings = {
          allowDiscards = true;
        };
        content = btrfsContent;
      };

      # Root level btrfs volumes for non-luks, or sub-content volumes for luks
      # NOTE: Rational for @-labels here: https://askubuntu.com/a/987116
      btrfsContent = {
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
          "@nix" = {
            mountpoint = "/nix";
            mountOptions = [
              "compress=zstd"
              "noatime"
            ];
          };
        }
        // (lib.optionalAttrs config.system.impermanence.enable {
          "@persist" = {
            mountpoint = "${config.hostSpec.persistFolder}";
            mountOptions = [
              "compress=zstd"
              "noatime"
            ];
          };
        })
        // (lib.optionalAttrs (config.system.disks.swapSize != null) {
          "@swap" = {
            mountpoint = "/.swapvol";
            swap.swapfile.size = config.system.disks.swapSize;
          };
        });
      };

      # Turn a list of drives into disko disks suitable for a raid array
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
    lib.mkIf cfg.enable {
      # Describe our primary and raid array disks, as well as relevant mdadm settings if needed
      disko.devices = {
        disk = {
          ${cfg.primaryDiskoLabel} = {
            type = "disk";
            device = cfg.primary;
            content = {
              type = "gpt";
              partitions = {
                ESP = {
                  priority = 1;
                  name = "ESP";
                  size = config.system.disks.bootSize;
                  type = "EF00";
                  content = {
                    type = "filesystem";
                    format = "vfat";
                    mountpoint = "/boot";
                    mountOptions = [ "defaults" ];
                  };
                };
              }
              // (
                let
                  # FIXME: Make make these configurable
                  name = (if cfg.luks.enable then "luks" else "root");
                in
                {
                  ${name} = {
                    size = "100%";
                    content = (if cfg.luks.enable then luksContent else btrfsContent);
                  };
                }
              );
            };
          };
        }
        // lib.optionalAttrs hasRaid (mkRaid cfg.raidLevel cfg.raidDisks);
      }
      // lib.optionalAttrs hasRaid {
        # FIXME: This could use a raidLuks and primaryLuks
        mdadm = {
          "raid${toString cfg.raidLevel}" = {
            type = "mdadm";
            level = cfg.raidLevel;
            content = {
              type = "luks";
              # FIXME:Not sure if we should make this name configurable
              name = "encrypted-storage";
              passwordFile = "/tmp/disko-password";
              settings = {
                allowDiscards = true;
                crypttabExtraOpts = [ "nofail" ];
              };
              # Add a boot.initrd.luks.devices entry to auto-decrypt
              initrdUnlock = if config.hostSpec.isMinimal then true else false;

              content = {
                type = "btrfs";
                extraArgs = [ "-f" ]; # force overwrite
                subvolumes = {
                  "@storage" = {
                    mountpoint = cfg.raidMountPath;
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "nofail"
                    ];
                  };
                };
              };
            };
          };
        };
      };

      # Unlock extra disks
      # https://wiki.nixos.org/wiki/Full_Disk_Encryption#Unlocking_secondary_drives
      #
      # FIXME: See if the secondary-unlock key can actually be part of sops,
      # which would be possible if systemd-cryptsetup@xxx.service runs after sops
      # service
      # https://github.com/ckiee/nixfiles/blob/aa0138bc4b183d939cd8d2e60bcf2828febada36/hosts/pansear/hardware.nix#L16
      # We may need to make our own systemd unit that tries to mount but that
      # isn't critical, so that we can ignore it in the event of an error (like
      # if you forget to update the UUID after bootstrap, etc). Not bothering for
      # now, as it's not pressing. The drives are already using the same
      # passphrase as the main drive, which we have recorded
      #
      # Find path with: ls /dev/disk/by-id/
      #
      environment = {
        etc.crypttab.text = lib.optionalString (!config.hostSpec.isMinimal) (
          lib.concatMapStringsSep "\n" (
            d:
            # FIXME: noauto doesn't work, so path has to be correct or boot fails
            # investigate a way to use x-systemd.automount mount or similar
            "${d.name} ${d.path} /luks-secondary-unlock.key noauto,nofail"
          ) cfg.extraDisks
        );
      }
      // lib.optionalAttrs config.system.impermanence.enable {
        persistence."${config.hostSpec.persistFolder}" = {
          files = [
            "/luks-secondary-unlock.key"
          ];
        };
      };

      # Prevent failure: mdadm: No mail address or alert command - not monitoring
      boot.swraid.mdadmConf = lib.optionalString hasRaid ''
        MAILADDR ${config.hostSpec.email.admin}
      '';

      # Override mdmonitor to log to syslog instead of emailing or alerting
      systemd.services."mdmonitor".environment = lib.optionalAttrs hasRaid {
        MDADM_MONITOR_ARGS = "--scan --syslog";
      };
    };
}
