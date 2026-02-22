# Some inspiration from:
#  - https://github.com/tiredofit/nix-modules/blob/5cb4be/nixos/service/monit.nix
#  - https://github.com/filipelsilva/nixos-config/blob/be22e8c1/modules/monit.nix
#
# TODO:
# - [ ] Should maybe enable daemon behind nginx proxy?
# - [ ] Add cpu temperature checks probably
# - [ ] Add a list of services to not alert on if down
# - [ ] Add a check for /nix/store size if gc is failing
{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.services.monit;
  secretConfig = "monit/secret-config";
  mail =
    assert (
      lib.assertMsg (config.mail-delivery.enable) "monit currently requires config.mail-delivery configured"
    );
    config.mail-delivery;

  hdTemp = pkgs.writeShellApplication {
    name = "hd-temp";
    runtimeInputs = lib.attrValues {
      inherit (pkgs) smartmontools jq;
    };
    text =
      # bash
      ''
        SMARTCTL_OUTPUT=$(smartctl --json=c --nocheck=standby -A "/dev/disk/by-id/$1")
        if [[ "$?" = "2" ]]; then
            echo "STANDBY"
            exit 0
        fi
        TEMPERATURE=$(jq '.temperature.current' <<< "$SMARTCTL_OUTPUT")
        echo "$TEMPERATURE"°C
        exit "$TEMPERATURE"
      '';
  };

  smartStatus = pkgs.writeShellApplication {
    name = "hd-status";
    runtimeInputs = lib.attrValues {
      inherit (pkgs) smartmontools jq;
    };
    text = # bash
      ''
        SMARTCTL_OUTPUT=$(smartctl --json=c --nocheck=standby -H "/dev/disk/by-id/$1")
        if [[ "$?" = "2" ]]; then
            echo "STANDBY"
            exit 0
        fi
        PASSED=$(jq ".smart_status.passed" <<< "$SMARTCTL_OUTPUT")
        if [ "$PASSED" = "true" ]
        then
            echo "PASSED"
            exit 0
        else
            echo "FAULTY"
            exit 1
        fi
      '';
  };

  # FIXME: Maybe add stuff missing from https://github.com/sam0rr/SD-EMMC-HEALTHCHECK
  emmcHealthStatus =
    disk:
    pkgs.writeShellApplication {
      name = "emmc-${disk}-health-status";
      runtimeInputs = lib.attrValues {
        inherit (pkgs) mmc-utils gawk coreutils;
      };
      text =
        let
          limits = cfg.health.disks.emmc.disks.${disk};
        in
        # bash
        ''
          CSD=$(mmc extcsd read /dev/disk/by-id/${disk})
          EOL=$(echo "$CSD" | grep "Pre EOL information" | awk '{print $NF}')
          LIFE_A=$(($(echo "$CSD" | grep "Life Time Estimation A" | awk '{print $NF}')*10))
          LIFE_B=$(($(echo "$CSD" | grep "Life Time Estimation B" | awk '{print $NF}')*10))

          ALERT=0

          function warn_lifetime {
            type=$1
            value=$2
            if ((value < 70)) then
              echo "eMMC Health: ${disk} Type $type lifetime surpassed configured limit, but still at safe limit"
            elif ((value >= 70 && 90 < value)) then
              echo "eMMC Health: WARNING: ${disk} Type $type lifetime in at $LIFE_A%. Will need replacement."
            elif ((value >= 90)) then
              echo "eMMC Health: CRITICAL: ${disk} Type $type lifetime in at $LIFE_A%. Imminent death."
            fi
          }

          if [[ "$EOL" -gt ${toString limits.reservedBlockLimit} ]]; then
            ALERT=1
            case "$EOL" in
                "0x01")
                    echo "eMMC Health: Normal"
                    ;;
                "0x02")
                    echo "eMMC Health: WARNING: 80% reserved blocks used"
                    ;;
                "0x03")
                    echo "eMMC Health: URGENT: 90% reserved blocks used"
                    ;;
                *)
                    echo "eMMC Health: Unknown or Invalid ($STATUS)"
                    ;;
            esac
          fi
          if [[ "$LIFE_A" -gt ${toString limits.lifeTimeTypeALimit} ]]; then
            ALERT=1
            warn_lifetime "A" "$LIFE_A"
          fi
          if [[ "$LIFE_B" -gt ${toString limits.lifeTimeTypeALimit} ]]; then
            ALERT=1
            warn_lifetime "B" "$LIFE_B"
          fi

          exit $ALERT
        '';
    };

  failedServices = pkgs.writeShellApplication {
    name = "failed-systemd-services";
    runtimeInputs = lib.attrValues {
      inherit (pkgs) systemd jq;
    };
    text = # bash
      ''
        FAILED_SERVICES=$(systemctl \
          --failed \
          --type=service \
          --output=json \
          --no-pager \
          | jq -r '.[] | select((.active // "") == "failed" or (.sub // "") == "failed") | .unit'
        )

        if [[ -n "$FAILED_SERVICES" ]]; then
          echo "Failed systemd services detected:"
          echo "$FAILED_SERVICES"
          exit 1
        fi
        exit 0
      '';
  };

  btrfsScrubStatus = pkgs.writeShellApplication {
    name = "btrfs-scrub-status";
    runtimeInputs = lib.attrValues {
      inherit (pkgs) btrfs-progs gawk;
    };
    # FIXME: if we already know a drive has errors, what do we do? perhaps we set a new baseline value
    # that defaults to 0 but that will equal whatever we expect the known number of errors on the fileSystem is?
    # then we pass that value as a second argument to the script?
    #
    text = # bash
      ''
        btrfs scrub status "$1" | awk '/uncorrectable/ {if ($2 > 0) exit 1}'
      '';
  };
in
{
  options =
    let
      mkInterval =
        {
          default ? "cfg.cycleDuration cycles",
          description ? "monit cycle ([number] cycles) or cron (* * * * *) interval",
        }:
        lib.mkOption {
          inherit default description;
          type = lib.types.str;
          apply = value: if (lib.hasInfix "cycles" value) then value else ''"${value}"'';
        };
    in
    {
      ${namespace}.services.monit = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          example = true;
          description = "Enables the monit service for monitoring and alerting on system resources";
        };
        extraConfig = lib.mkOption {
          type = lib.types.str;
          description = "Extra configuration to append to the generated config";
          default = "";
        };
        email = lib.mkOption {
          type = lib.types.submodule {
            options = {
              to = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ config.hostSpec.email.admin ];
                example = [ "admin@example.com" ];
                description = "List of emails to send UPS notifications to";
              };
              from = lib.mkOption {
                type = lib.types.str;
                default = config.hostSpec.email.notifier;
                example = "notifications@example.com";
                description = "Email address to send UPS notifications from";
              };
            };
          };
          default = { };
        };
        cycleDuration = lib.mkOption {
          default = 30;
          type = lib.types.int;
          description = "Default cycle duration in seconds";
        };
        health = {
          disks = {
            enable = lib.mkOption {
              default = false;
              type = lib.types.bool;
              description = "Enables disk health and temperature monitoring";
            };
            temperature = {
              limit = lib.mkOption {
                default = "65"; # Some docs say ~70 is around the typical limit, so 65 for initial testing
                type = lib.types.str;
                description = "Limit temperature for disks";
              };
              interval = mkInterval {
                # Every 30 minutes
                default = "0,30 * * * *";
              };
            };
            smart = {
              disks = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                description = "List of disks names to monitor with S.M.A.R.T tools";
              };
              interval = mkInterval {
                # Every 12 hours
                default = "0 0,12 * * *";
              };
            };
            emmc = {
              enable = lib.mkOption {
                default = false;
                type = lib.types.bool;
                description = "Enables emmc health check";
              };
              disks = lib.mkOption {
                type = lib.types.attrsOf (
                  lib.types.submodule {
                    options = {
                      reservedBlockLimit = lib.mkOption {
                        default = 2;
                        type = lib.types.int;
                        description = "Reserved block level to warn on: 1 normal, 2 warning, 3 urgent";
                      };
                      lifeTimeTypeALimit = lib.mkOption {
                        default = 60;
                        type = lib.types.int;
                        description = "Remaining life time type A (SLC) warning threshold";
                      };
                      lifeTimeTypeBLimit = lib.mkOption {
                        default = 60;
                        type = lib.types.int;
                        description = "Remaining life time type B (MLC/TLC) warning threshold";
                      };
                    };
                  }
                );
                description = "Set of disks to monitor with mmc-utils. Set names MUST match /dev/disk/by-id/<disk> name";
                example = {
                  "mmc-SCA64G_0x56567305" = {
                    reservedBlockLimit = 3; # Already > 80% of reserve block use, so now warn on 90% only
                    lifeTimeTypeBLimit = 80; # Type B lifetime already passed default 60%, so warn on 80%
                  };
                };
                default = { };
              };
              interval = mkInterval {
                # Every sunday
                default = "* * * * 0";
              };
            };
          };
          services = {
            enable = lib.mkOption {
              default = true;
              type = lib.types.bool;
              description = "Enables failed systemd services check";
            };
            interval = mkInterval {
              # Every 60 minutes
              default = "0 * * * *";
            };
          };
          mdadm = {
            enable = lib.mkOption {
              type = lib.types.bool;
              description = "Enables mdadm raid array status monitoring";
              default = false;
            };
            disks = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "List of mdadm arrays to check";
            };
            interval = mkInterval {
              # Every 30 minutes
              default = "0,30 * * * *";
            };
          };
          btrfs = {
            enable = lib.mkOption {
              type = lib.types.bool;
              description = "Enables btrfs scrub status monitoring. Relies on services.btrfs.autoScrub";
              default = false;
            };
            fileSystems = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "List of btrfs paths to monitor";
            };
            interval = mkInterval {
              # Daily at 3am
              default = "0 3 * * *";
            };
          };
        };
        usage = {
          fileSystem = {
            enable = lib.mkOption {
              default = true;
              type = lib.types.bool;
              description = "Enables fileSystem usage monitoring";
            };
            fileSystems = lib.mkOption {
              type = lib.types.attrsOf (
                lib.types.submodule {
                  options = {
                    limit = lib.mkOption {
                      default = "90%";
                      type = lib.types.str;
                      description = "Limit for usage monitoring";
                    };
                    path = lib.mkOption {
                      default = "/";
                      type = lib.types.str;
                      description = "Path to monitor";
                    };
                  };
                }
              );
              # single list entry with the default submodule values
              default = {
                rootfs = { };
              };
              description = "List of disks to monitor";
            };
            interval = mkInterval {
              # Every 10 minutes based on default cycle of 30s
              default = "20 cycles";
            };
          };
        };
      };
    };
  config =
    let
      emmcDiskNames = lib.optional cfg.health.disks.emmc.enable (
        lib.attrNames cfg.health.disks.emmc.disks
      );
      allDiskNames = emmcDiskNames ++ cfg.health.disks.smart.disks;
    in
    lib.mkIf cfg.enable {
      services.monit = {
        enable = true;
        config =
          let
            monitDisks = lib.optionalString cfg.usage.fileSystem.enable (
              let
                inherit (cfg.usage.fileSystem) fileSystems;
              in
              lib.concatMapStringsSep "\n" (name: ''
                check fileSystem ${name} with path ${fileSystems.${name}.path}
                  every ${cfg.usage.fileSystem.interval}
                  if space usage > ${fileSystems.${name}.limit} then alert
              '') (lib.attrNames fileSystems)
            );

            monitDriveTemperature = drive: ''
              check program "drive temperature: ${drive}" with path "${lib.getExe hdTemp} ${drive}"
                 every ${cfg.health.disks.temperature.interval}
                 if status > ${cfg.health.disks.temperature.limit} then alert
                 group health'';
            monitDriveTemperatures = lib.optionalString cfg.health.disks.enable (
              lib.strings.concatMapStringsSep "\n" monitDriveTemperature allDiskNames
            );

            monitDriveSmartStatus = drive: ''
              check program "drive smart status: ${drive}" with path "${lib.getExe smartStatus} ${drive}"
                 every ${cfg.health.disks.smart.interval}
                 if status > 0 then alert
                 group health'';
            monitDriveSmartStatuses = lib.optionalString cfg.health.disks.enable (
              lib.strings.concatMapStringsSep "\n" monitDriveSmartStatus cfg.health.disks.smart.disks
            );

            monitRaidArrayStatus = drive: ''
              check program "raid status: ${builtins.baseNameOf drive}" with path "${pkgs.mdadm}/bin/mdadm --misc --detail --test /dev/${drive}"
                if status != 0 then alert
            '';
            monitRaidArrayStatuses = lib.optionalString cfg.health.mdadm.enable (
              lib.strings.concatMapStringsSep "\n" monitRaidArrayStatus cfg.health.mdadm.disks
            );

            monitEmmcStatus = drive: ''
              check program "emmc health: ${drive}" with path "${lib.getExe (emmcHealthStatus drive)}"
                every ${cfg.health.disks.emmc.interval}
                if status != 0 then alert
            '';
            monitEmmcStatuses = lib.optionalString cfg.health.disks.emmc.enable (
              lib.strings.concatMapStringsSep "\n" monitEmmcStatus emmcDiskNames
            );

            # This doesn't actually scrub, just checks the status of the scrub
            # the autoScrub service did, so no harm running it more often (daily
            # below). FIXME: could sync it somehow with autoScrub service timer
            monitBtrfsScrubStatus = path: ''
              check program "btrfs scrub: ${path}" with path "${lib.getExe btrfsScrubStatus} ${path}"
                every ${cfg.health.btrfs.interval}
                if status != 0 then alert
            '';
            monitBtrfsScrubStatuses = lib.optionalString cfg.health.btrfs.enable (
              lib.strings.concatMapStringsSep "\n" monitBtrfsScrubStatus cfg.health.btrfs.fileSystems
            );

            monitFailedServices = lib.optionalString cfg.health.services.enable ''
              check program "systemd services" with path "${lib.getExe failedServices}"
                # Every hour
                every ${cfg.health.services.interval}
                group system
                if status > 0 then alert
            '';

            # FIXME: Allow email format customization
            monitConfig = ''
              set daemon ${toString cfg.cycleDuration}
              ${lib.concatMapStringsSep "\n" (a: "set alert ${a} but not on { instance }") cfg.email.to}
              set logfile /var/log/monit.log

              include ${config.sops.templates.${secretConfig}.path}

              set mail-format {
               from: ${cfg.email.from}
               subject: [$HOST: monit]: $SERVICE - $EVENT on $DATE
               message: $DESCRIPTION
              }
            '';
          in
          lib.concatStringsSep "\n" [
            monitConfig
            monitDisks
            monitDriveTemperatures
            monitDriveSmartStatuses
            monitRaidArrayStatuses
            monitEmmcStatuses
            monitBtrfsScrubStatuses
            monitFailedServices
            cfg.extraConfig
          ];
      };
      # Start late enough that any additional drives are decrypted/mounted
      systemd.services.monit = {
        after = [
          "local-fs.target"
          "remote-fs.target"
          "network-online.target"
        ];
      };

      sops.templates.${secretConfig} =
        let
          password = "passwords/${if mail.useRelay then "postfix-relay" else "msmtp"}";
        in
        {
          content = ''
            set mailserver ${mail.smtpHost} port ${toString mail.smtpPort}
              username "${mail.smtpUser}" password "${config.sops.placeholder."${password}"}"
              using tls
          '';
          owner = "root";
          mode = "400";
        };
    };
}
