# Options to determing how msmtp will be used to deliver email notifications
{ config, lib, ... }:
let
  cfg = config.mail-delivery;
  secret = "passwords/${if cfg.useRelay then "postfix-relay" else "msmtp"}";
in
{
  options.mail-delivery = {
    enable = lib.mkEnableOption "mail-delivery";
    useRelay = lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Whether or not to use postfix mail relay for mail delivery";
    };

    emailFrom = lib.mkOption {
      type = lib.types.str;
      description = "Email address from which to send notifications";
    };

    users = lib.mkOption {
      default = [ config.hostSpec.primaryUsername ];
      type = lib.types.listOf lib.types.str;
      description = "Users added to the group with mail delivery password access";
    };

    group = lib.mkOption {
      default = "msmtp-secret-users";
      type = lib.types.str;
      description = "Name of group controlling access to mail delivery password";
    };

    smtpUser = lib.mkOption {
      type = lib.types.str;
      description = "Username of smtp user";
    };

    smtpPort = lib.mkOption {
      default = (if cfg.useRelay then 25 else 587);
      type = lib.types.int;
      description = "Port number for smtp server";
    };

    smtpHost = lib.mkOption {
      type = lib.types.str;
      description = "Domain of smtp server";
    };

  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.group} = {
      members = cfg.users;
    };
    sops.secrets."${secret}" = {
      group = cfg.group;
      mode = "0440";
    };

    # FIXME: Likely need this on darwin: https://github.com/NixOS/nixpkgs/issues/195532
    programs.msmtp = {
      enable = true;
      setSendmail = true; # set the system sendmail to msmtp's
      defaults = {
        syslog = true;
      };

      accounts =
        let
          commonAttrs = {
            auth = true;
            tls = true;
            tls_starttls = true;
            port = cfg.smtpPort;
            user = cfg.smtpUser;
            from = cfg.emailFrom;
            # Watch logs with `journalctl --facility=mail`
            syslog = "LOG_MAIL";
            #logfile /tmp/msmtp.log
          };
        in
        {
          "default" = {
            host = cfg.smtpHost;
            passwordeval = "cat ${config.sops.secrets.${secret}.path}";
          }
          // commonAttrs;
          # For cases where postfix relay might be down, like heartbeat-check
          #"direct" = {
          #  host = "localhost";
          #  port = 25;
          #} // commonAttrs;
        };
    };
  };
}
