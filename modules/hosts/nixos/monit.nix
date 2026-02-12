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
# - [ ] Add btrfs failure checks probably
# - [ ] Add cpu temperature checks probably
# - [ ] Add other services to have opt-in entries to monitor if the service fails
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
      };
      usage = {
        filesystem = {
          enable = lib.mkOption {
            default = true;
            type = lib.types.bool;
            description = "Enables filesystem usage monitoring";
          };
          filesystems = lib.mkOption {
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
          monitDisks = lib.optionalString cfg.usage.filesystem.enable (
            let
              inherit (cfg.usage.filesystem) filesystems;
            in
            lib.concatMapStringsSep "\n" (name: ''
              check filesystem ${name} with path ${filesystems.${name}.path}
                if space usage > ${filesystems.${name}.limit} then alert
            '') (lib.attrNames filesystems)
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
