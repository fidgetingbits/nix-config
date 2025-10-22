{ config, lib, ... }:

let
  # FIXME: This should be options probably the the options get set elsewhere eventually
  #
  domain = config.hostSpec.domain;
  notifier = "box@${domain}";
  useRelay = config.mail-delivery.useRelay;
  secret = "passwords/${if useRelay then "postfix-relay" else "msmtp"}";
  host = if useRelay then "mail.${domain}" else "smtp.protonmail.ch";
  # moon ISP blocks outgoing 25 it seems
  port = if useRelay then 25 else 587;
  user = if useRelay then config.hostSpec.hostname else notifier;
  logfile = "~/.msmtp.log";
in
{
  options.mail-delivery = {
    useRelay = lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Whether or not to use postfix mail relay for mstmp delivery";
    };
  };

  config = {
    sops.secrets =
      { }
      // (lib.mkIf useRelay {
        "passwords/postfix-relay" = {
          owner = config.users.users.${config.hostSpec.username}.name;
          inherit (config.users.users.${config.hostSpec.username}) group;
        };
      })
      // (lib.mkIf (!useRelay) {
        "passwords/msmtp" = {
          owner = config.users.users.${config.hostSpec.username}.name;
          inherit (config.users.users.${config.hostSpec.username}) group;
        };
      });

    # FIXME: Likely need this on darwin: https://github.com/NixOS/nixpkgs/issues/195532
    programs.msmtp = {
      enable = true;
      setSendmail = true; # set the system sendmail to msmtp's

      accounts =
        let
          commonAttrs = {
            inherit user port logfile;
            auth = true;
            tls = true;
            tls_starttls = true;
            from = notifier;
          };
        in
        {
          "default" = {
            inherit host;
            user = config.networking.hostName;
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
