# Some inspiration from:
#  - https://github.com/tiredofit/nix-modules/blob/5cb4be/nixos/service/monit.nix
#
# To read:
# Uses smart tools:
#  - https://github.com/filipelsilva/nixos-config/blob/be22e8c1/modules/monit.nix
# - https://github.com/charludo/nix/blob/65d6c9d/modules/nixos/monit.nix#L202
#
# TODO:
# - [ ] Should maybe enable daemon behind nginx proxy?
# - [ ] Add cpu temperature checks probably
# - [ ] Add other services to have opt-in entries to alert/monitor if the service fails
# - [ ] Would mdmonitor make more sense here if using raid?
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
    text = ''
      SMARTCTL_OUTPUT=$(smartctl --json=c --nocheck=standby -A "/dev/$1")
      if [[ "$?" = "2" ]]; then
          echo "STANDBY"
          exit 0
      fi
      TEMPERATURE=$(jq '.temperature.current' <<< "$SMARTCTL_OUTPUT")
      echo "$TEMPERATURE"°C
      exit "$TEMPERATURE"
    '';
  };

  hdStatus = pkgs.writeShellApplication {
    name = "hd-status";
    runtimeInputs = lib.attrValues {
      inherit (pkgs) smartmontools jq;
    };
    text = ''
      SMARTCTL_OUTPUT=$(smartctl --json=c --nocheck=standby -H "/dev/$1")
      if [[ "$?" = "2" ]]; then
          echo "STANDBY"
          exit 0
      fi
      PASSED=$(jq '.smart_status.passed' <<< "$SMARTCTL_OUTPUT")
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

  btrfsScrubStatus = pkgs.writeShellApplication {
    name = "btrfs-scrub-status";
    runtimeInputs = lib.attrValues {
      inherit (pkgs) btrfs-progs gawk;
    };
    # FIXME: if we already know a drive has errors, what do we do? perhaps we set a new baseline value
    # that defaults to 0 but that will equal whatever we expect the known number of errors on the fileSystem is?
    # then we pass that value as a second argument to the script?
    #
    text = ''
      btrfs scrub status "$1" | awk '/uncorrectable/ {if ($2 > 0) exit 1}'
    '';
  };
in
{
  options = {
    ${namespace}.services.monit = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        example = true;
        description = "Enables the monit service for monitoring and alerting on system resources";
      };
      settings = {
        checkInterval = lib.mkOption {
          default = "30";
          type = lib.types.str;
          description = "Check services at however many second intervals";
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
      };
      health = {
        disk = {
          enable = lib.mkOption {
            default = false;
            type = lib.types.bool;
            description = "Enables disk health and temperature monitoring";
          };
          tempLimit = lib.mkOption {
            default = "65"; # Some docs say ~70 is around the typical limit, so 65 for initial testing
            type = lib.types.str;
            description = "Limit temperature for disks";
          };
          disks = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Disk name to monitor";
          };
        };
        mdadm = {
          enable = lib.mkOption {
            type = lib.types.bool;
            description = "Enables mdadm raid array status monitoring";
            default = false;
          };
          # FIXME:This could default to the list of mdadm arrays we already define in disks?
          disks = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "List of mdadm arrays to check";
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
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
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
                if space usage > ${fileSystems.${name}.limit} then alert
            '') (lib.attrNames fileSystems)
          );

          monitorDriveTemperature = drive: ''
            check program "drive temperature: ${drive}" with path "${lib.getExe hdTemp} ${drive}"
               # Every 30 minutes
               every "0,30 * * * *"
               if status > ${cfg.health.disk.tempLimit} then alert
               group health'';
          monitorDriveTemperatures = lib.optionalString cfg.health.disk.enable (
            lib.strings.concatMapStringsSep "\n" monitorDriveTemperature cfg.health.disk.disks
          );
          monitorDriveStatus = drive: ''
            check program "drive status: ${drive}" with path "${lib.getExe hdStatus} ${drive}"
               # Every 12 hours
               every "0 0,12 * * *"
               if status > 0 then alert
               group health'';
          monitorDriveStatuses = lib.optionalString cfg.health.disk.enable (
            lib.strings.concatMapStringsSep "\n" monitorDriveStatus cfg.health.disk.disks
          );
          monitorRaidArrayStatus = drive: ''
            check program "raid status: ${drive}" with path "${pkgs.mdadm}/bin/mdadm --misc --detail --test /dev/${drive}"
              if status != 0 then alert
          '';
          monitorRaidArrayStatuses = lib.optionalString cfg.health.mdadm.enable (
            lib.strings.concatMapStringsSep "\n" monitorRaidArrayStatus cfg.health.mdadm.disks
          );
          # This doesn't actually scrub, just checks the status of the scrub
          # the autoScrub service did, so no harm running it more often (daily
          # below). FIXME: could sync it somehow with autoScrub service timer
          monitorBtrfsScrubStatus = path: ''
            check program "btrfs scrub: ${path}" with path "${lib.getExe btrfsScrubStatus} ${path}"
              every "0 3 * * *"
              if status != 0 then alert
          '';
          monitorBtrfsScrubStatuses = lib.optionalString cfg.health.btrfs.enable (
            lib.strings.concatMapStringsSep "\n" monitorBtrfsScrubStatus cfg.health.btrfs.fileSystems
          );

          monitConfig = ''
            set daemon 30
            ${lib.concatMapStringsSep "\n" (a: "set alert ${a} but not on { instance }") cfg.settings.email.to}
            set logfile /var/log/monit.log

            include ${config.sops.templates.${secretConfig}.path}

            set mail-format {
             from: ${cfg.settings.email.from}
             subject: [$HOST: monit]: $EVENT on $DATE
             message: $DESCRIPTION
            }
          '';
        in
        lib.concatStringsSep "\n" [
          monitConfig
          monitDisks
          monitorDriveTemperatures
          monitorDriveStatuses
          monitorRaidArrayStatuses
          monitorBtrfsScrubStatuses
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
