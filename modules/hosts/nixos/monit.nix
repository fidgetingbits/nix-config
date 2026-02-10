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
    ${lib.concatMapStringsSep "\n" (a: "set alert ${a}") cfg.notify.to}
    set logfile /var/log/monit.log

    include ${config.sops.templates.${secretConfig}.path}

    set mail-format {
     from: ${cfg.notify.from}
     subject: [$HOST: $SERVICE]: $EVENT on $DATE
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
      notify = lib.mkOption {
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
  };
  config = lib.mkIf cfg.enable {
    services.monit = {
      enable = true;
      config = monitConfig;
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
