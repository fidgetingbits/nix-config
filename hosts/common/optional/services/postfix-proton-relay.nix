{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:
let
  sopsFolder = (builtins.toString inputs.nix-secrets) + "/sops";
  postfixPasswdFile = config.sops.secrets."postfix/sasl_passwd";
  passwdDir = "/var/lib/postfix/data/passwords";
in
{
  # Good reference here
  # Most options are described here: http://www.postfix.org/SASL_README.html
  # https://github.com/nqpz/nielx/blob/52aba4625285471ac9514cf5ea19293047ab273c/nielx/postfix_relayhost.nix#L47
  # Use journalctl -u postfix to see logs
  services.postfix =
    let
      domain = "mail.${config.hostSpec.domain}";
    in
    {
      enable = true;

      settings.main = {
        relayHost = "smtp.protonmail.ch:587";
        ##
        # smtp_xxx is to auth to the relay
        ##
        smtp_sasl_auth_enable = "yes";
        # FIXME(postfix): Possibly rename sasl_passwd to be proton specific, in case eventually have multiple relays?
        # FIXME(postfix): Use texthash to avoid needing the trick with postmap copying
        smtp_sasl_password_maps = "hash:${passwdDir}/sasl_passwd";
        #smtp_tls_wrappermode = "yes";
        smtp_tls_security_level = "encrypt";
        smtp_tls_mandatory_protocols = "!SSLv2, !TLSv1, !TLSv1.1";
        #tls_high_cipherlist = "ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256";
        smtp_tls_mandatory_ciphers = "high";
        smtp_tls_loglevel = "2";
        # proton uses PLAIN, so must allow plaintext for TLS
        smtp_sasl_security_options = "noanonymous";
        smtp_sasl_tls_security_options = "noanonymous";
        smtp_tls_note_starttls_offer = "yes";
        debug_peer_level = "5";
        debug_peer_list = "smtp.protonmail.ch";

        ##
        # smtpd_xxx is for receiving mail
        ##
        smtpd_relay_restrictions = "permit_sasl_authenticated,reject_unauth_destination";
        smtpd_helo_restrictions = "permit_sasl_authenticated,reject_unauth_destination";
        smtpd_sasl_auth_enable = "yes";
        smtpd_sasl_local_domain = config.hostSpec.domain;
        smtpd_sasl_security_options = "noanonymous";
        smtpd_sasl_tls_security_options = "$smtpd_sasl_security_options";
        # FIXME: This shows a warning in postfix check
        #  warning: /etc/postfix/main.cf: support for parameter "smtpd_use_tls" will be removed; instead, specify "smtpd_tls_security_level"
        smtpd_use_tls = "yes";
        smtpd_sasl_type = "dovecot";
        smtpd_sasl_path = "private/auth";
        smtpd_tls_security_level = "encrypt";
        smtpd_tls_auth_only = "yes";
        smtpd_tls_cert_file = "/var/lib/acme/${domain}/full.pem";
        smtpd_tls_key_file = "/var/lib/acme/${domain}/key.pem";
        smtpd_tls_CAfile = "/var/lib/acme/${domain}/fullchain.pem";
      };
    };

  sops.secrets."postfix/sasl_passwd" = {
    sopsFile = "${sopsFolder}/${config.hostSpec.hostName}.yaml";
    # IMPORTANT: If this isn't in /etc/postfix.local, then postmap can't created sasl_passwd.db,
    # because of permissions for /var/secret
    owner = config.services.postfix.user;
  };

  # There seems to be a systemd protection that prevents /etc/ modification as user postfix, so we
  # hack around it in order to generate sasl_passwd.db
  systemd.services.postfix.preStart = ''
    ${lib.getBin pkgs.coreutils}/bin/mkdir -pv ${passwdDir} || true
    ${lib.getBin pkgs.coreutils}/bin/cp -v "${postfixPasswdFile.path}" "${passwdDir}/sasl_passwd"
    ${lib.getBin pkgs.coreutils}/bin/chown -R ${config.services.postfix.user} ${passwdDir}
    ${lib.getBin pkgs.postfix}/sbin/postmap "${passwdDir}/sasl_passwd"
  '';
  networking.firewall.allowedTCPPorts = [ 25 ];

  security.acme.certs."mail.${config.hostSpec.domain}" = {
    #domains = [ "mail.${config.hostSpec.domain}" ];
    extraDomainNames =
      let
        domain = "${config.hostSpec.hostName}.${config.hostSpec.domain}";
      in
      [
        domain
        "mail.${domain}"
      ];
    postRun = "systemctl restart postfix.service";
    group = "postfix";
    email = config.hostSpec.email.letsEncrypt;
    dnsProvider = "gandiv5";
    credentialsFile = config.sops.secrets."tokens/gandi".path;
    dnsPropagationCheck = true;
  };

  # For passwd gen use `just dovecot-hash`
  # Test auth with swaks
  services.dovecot2 =
    let
      passwdFile = config.sops.secrets.dovecot.path;
    in
    {
      enable = true;
      enablePAM = false;
      enableImap = false; # This is to stop imap listening, despite empty protocols= below.
      mailLocation = "none";
      protocols = [ ]; # Don't run any servers, only auth

      extraConfig = ''
        # Disable all protocols

        # Enable auth service
        auth_debug = yes
        service auth {
          unix_listener  /var/lib/postfix/queue/private/auth {
            mode = 0660
            user = postfix
            group = postfix
          }
        }

        # Configure authentication
        auth_mechanisms = plain login

        # Use nix-secrets passwd file for atuh
        passdb {
          driver = passwd-file
          args = ${passwdFile}
        }
        userdb {
          driver = static
          args = uid=postfix gid=postfix home=/var/spool/mail/%u
        }
      '';
    };

  sops.secrets.dovecot = {
    sopsFile = "${sopsFolder}/${config.hostSpec.hostName}.yaml";
  };
}
