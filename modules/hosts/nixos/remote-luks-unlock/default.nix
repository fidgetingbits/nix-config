{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.remoteLuksUnlock;
in
{
  options = {
    services.remoteLuksUnlock = {
      enable = lib.mkEnableOption "Boot-time remote LUKS decrypt unlock service";
      key = lib.mkOption rec {
        type = lib.types.path;
        default = lib.custom.relativeToRoot "hosts/nixos/${config.hostSpec.hostName}/initrd_ed25519_key";
        example = default;
        description = "sshd private key as generated with ssh-keygen -t ed25519 -f initrd_ed25519_key or similar.\nNOTE: This file should be encrypted with git-crypt or similar. See .gitattributes for example";
      };
      notify = lib.mkOption {
        type = lib.types.bool;
        default = true;
        example = true;
        description = "Whether or not to configure email notification on boot to indicate SSH-based LUKs unlock is read";
      };
    };
  };

  config = lib.mkIf config.services.remoteLuksUnlock.enable {
    boot.initrd =
      let
        luksReadyScript = pkgs.writeShellScript "luks-ready-notify" ''
          ${pkgs.msmtp}/bin/msmtp -C /etc/msmtprc --logfile /dev/null -t <<EOF
          Subject: [${config.networking.hostName}: boot] LUKS Unlock Ready
          To: ${config.hostSpec.email.admin}

          ${config.networking.hostName} is booted and ssh for LUKS unlock is ready.
          EOF
        '';
      in
      {
        luks.forceLuksSupportInInitrd = true;
        # Setup the host key as a secret in initrd, so it's not exposed in the /nix/store
        # this is all too earlier for sops
        secrets = lib.mkForce {
          "/etc/secrets/initrd/ssh_host_ed25519_key" = cfg.key;
          "/etc/msmtprc" = pkgs.writeText "msmtprc" ''
            defaults
            syslog on

            account default
            auth on
            from ${config.hostSpec.email.luksUnlock}
            host ${config.hostSpec.email.externalServer}
            password ${lib.readFile ./secret}
            port ${toString config.hostSpec.email.externalPort}
            syslog LOG_MAIL
            tls on
            tls_starttls on
            tls_certcheck off
            user ${config.hostSpec.email.luksUnlock}
          '';
        };
        network = {
          enable = true;
          ssh = {
            enable = true;
            port = config.hostSpec.networking.ports.tcp.ssh;
            authorizedKeys = config.users.users.${config.hostSpec.username}.openssh.authorizedKeys.keys;
            hostKeys = [ "/etc/secrets/initrd/ssh_host_ed25519_key" ];
          };
        };

        systemd = {
          enable = true;
          # emergencyAccess = true;
          users.root.shell = "/bin/systemd-tty-ask-password-agent";
        }
        # Optionally dispatch email when system enters remote unlock state
        //
          lib.optionalAttrs cfg.notify

            {
              extraBin = {
                msmtp = "${pkgs.msmtp}/bin/msmtp";
                luks-ready-notify = luksReadyScript;
              };

              services.luks-ready-notify = {
                description = "Email notification when LUKS unlock via SSH is ready";
                after = [
                  "initrd-network.target"
                  "initrd-sshd.service"
                ];
                wantedBy = [ "initrd.target" ];

                serviceConfig = {
                  Type = "oneshot";
                  ExecStart = "${luksReadyScript}";
                  StandardOutput = "journal";
                  StandardError = "journal";
                };
              };
            };
      };
  };
}
