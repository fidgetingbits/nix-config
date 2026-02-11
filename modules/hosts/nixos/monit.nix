# Some inspiration from:
#  - https://github.com/tiredofit/nix-modules/blob/5cb4be/nixos/service/monit.nix
#
# To read:
#  - https://github.com/filipelsilva/nixos-config/blob/be22e8c1/modules/monit.nix
{
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
      usage = {
        filesystem = {
          enable = lib.mkOption {
            default = true;
            type = lib.types.bool;
            description = "Enables filesystem usage monitoring";
          };
          disks = lib.mkOption {
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
          monitDisks =
            if cfg.usage.filesystem.enable then
              let
                disks = cfg.usage.filesystem.disks;
              in
              lib.concatMapStringsSep "\n" (name: ''
                check filesystem ${name} with path ${disks.${name}.path}
                  if space usage > ${disks.${name}.limit} then alert
              '') (lib.attrNames disks)
            else
              "";
        in
        lib.concatStringsSep "\n" [
          monitConfig
          monitDisks
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
