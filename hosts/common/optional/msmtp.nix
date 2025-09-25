{ config, ... }:
{
  sops.secrets = {
    "passwords/postfix-relay" = {
      owner = config.users.users.${config.hostSpec.username}.name;
      inherit (config.users.users.${config.hostSpec.username}) group;
    };
  };

  # FIXME: Likely need this on darwin: https://github.com/NixOS/nixpkgs/issues/195532
  programs.msmtp = {
    enable = true;
    setSendmail = true; # set the system sendmail to msmtp's

    accounts =
      let
        commonAttrs = {
          auth = true;
          tls = true;
          tls_starttls = true;
          from = "box@${config.hostSpec.domain}";
          logfile = "~/.msmtp.log";

        };
      in
      {
        "default" = {
          # FIXME(msmtp): Make this configurable for remotely managed systems
          host = "mail.${config.hostSpec.domain}";
          user = config.networking.hostName;
          passwordeval = "cat ${config.sops.secrets."passwords/postfix-relay".path}";
        }
        // commonAttrs;
        # For cases where postfix relay might be down, like heartbeat-check
        #"direct" = {
        #  host = "localhost";
        #  port = 25;
        #} // commonAttrs;
      };
  };
}
