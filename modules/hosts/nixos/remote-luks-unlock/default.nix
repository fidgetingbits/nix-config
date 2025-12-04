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
      unlockOnly = lib.mkOption {
        type = lib.types.bool;
        default = true;
        example = false;
        description = "Only allow unlocking of the root filesystem as opposed to general SSH access";
      };
      ssh = lib.mkOption {
        type = lib.types.submodule {
          options = {
            port = lib.mkOption {
              type = lib.types.int;
              default = config.hostSpec.networking.ports.tcp.ssh;
              example = 22;
              description = "Port to listen for incoming SSH connections for remote LUKS unlock";
            };
            users = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ config.hostSpec.username ];
              example = [
                "alice"
                "bob"
              ];
              #checks = ({ value, ... }: lib.all (n: config.users.users ? n) value);
              description = "List of users whose authorized keys will be allowed to LUKs unlock this host";
            };
            key = lib.mkOption rec {
              type = lib.types.path;
              default = lib.custom.relativeToRoot "hosts/nixos/${config.hostSpec.hostName}/initrd_ed25519_key";
              example = default;
              description = ''
                sshd private key as generated with `ssh-keygen -t ed25519 -f initrd_ed25519_key` or similar.\n
                NOTE: This file should be encrypted with git-crypt or similar. See .gitattributes for example'';
            };
          };
        };
        default = { };
      };
      notify = lib.mkOption {
        type = lib.types.submodule {
          options = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              example = true;
              description = "Whether or not to configure email notification on boot to indicate SSH-based LUKs unlock is read";
            };
            to = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ config.hostSpec.email.admin ];
              example = [ "admin@example.com" ];
              description = "List of emails to send unlock notifications to";
            };
            from = lib.mkOption {
              type = lib.types.str;
              default = config.hostSpec.email.luksUnlock;
              example = "notifications@example.com";
              description = "Email address to send unlock notifications from";
            };
            server = lib.mkOption {
              type = lib.types.str;
              default = config.hostSpec.email.externalServer;
              example = "smtp.protonmail.ch";
              description = "Notification SMTP server";
            };
            port = lib.mkOption {
              type = lib.types.int;
              default = lib.toInt config.hostSpec.email.externalPort;
              example = 587;
              description = "Port of notification SMTP Server";
            };
            user = lib.mkOption {
              type = lib.types.str;
              default = config.hostSpec.email.luksUnlock;
              example = "notifications@example.com";
              description = "SMTP username for authentication";
            };
            password = lib.mkOption {
              type = lib.types.str;
              default = lib.readFile ./secret;
              example = "foo";
              description = ''
                SMTP password for authentication.\n
                NOTE: the default './secret' file read should be encrypted using git-crypt or similar. See .gitattributes for example
              '';
            };
          };
        };
        default = { };
      };
    };
  };

  config = lib.mkIf config.services.remoteLuksUnlock.enable {
    boot.initrd =
      let
        recipients = lib.concatStringsSep ", " cfg.notify.to;
        host = config.networking.hostName;
        luksReadyScript = pkgs.writeShellScript "luks-ready-notify" ''
          ${pkgs.msmtp}/bin/msmtp -C /etc/msmtprc --logfile /dev/null -t <<EOF
          Subject: [${host}: boot] LUKS Unlock Ready
          To: ${recipients}

          ${host} is booted and ssh for LUKS unlock is ready
          EOF
        '';
      in
      {
        luks.forceLuksSupportInInitrd = true;
        # Setup the host key as a secret in initrd, so it's not exposed in the /nix/store
        # this is all too earlier for sops
        secrets = lib.mkForce (
          {
            "/etc/secrets/initrd/ssh_host_ed25519_key" = cfg.ssh.key;
          }
          // lib.optionalAttrs cfg.notify.enable {
            "/etc/msmtprc" = pkgs.writeText "msmtprc" ''
              defaults
              syslog on

              account default
              auth on
              from ${cfg.notify.from}
              host ${cfg.notify.server}
              password ${cfg.notify.password}
              port ${toString cfg.notify.port}
              syslog LOG_MAIL
              tls on
              tls_starttls on
              tls_certcheck off
              user ${cfg.notify.user}
            '';
          }
        );
        network = {
          enable = true;
          ssh = {
            enable = true;
            port = cfg.ssh.port;
            authorizedKeys =
              cfg.ssh.users
              |> map (user: config.users.users.${user}.openssh.authorizedKeys.keys)
              |> lib.concatLists;
            hostKeys = [ "/etc/secrets/initrd/ssh_host_ed25519_key" ];
            extraConfig = ''
              PrintMotd yes
            '';
          };
        };

        systemd = {
          enable = true;
          emergencyAccess = cfg.unlockOnly;
          contents."/etc/motd".text = ''
            Use systemd-tty-ask-password-agent
          '';
          users.root.shell = if cfg.unlockOnly then "/bin/systemd-tty-ask-password-agent" else "/bin/bash";

          extraBin =
            lib.optionalAttrs (!cfg.unlockOnly) {
              ip = lib.getExe' pkgs.iproute2 "ip";
              ping = lib.getExe' pkgs.iptuils "ping";
            }
            // lib.optionalAttrs cfg.notify.enable {
              msmtp = lib.getExe' pkgs.msmtp "msmtp";
              luks-ready-notify = luksReadyScript;
            };

          # Configure system to auto-reboot instead of hang on emergency
          # this allows retrying if passphrase was pasted incorrectly
          targets.emergency.wants = [
            "initrd-reboot.timer"
          ];

          timers = {
            initrd-reboot = {
              unitConfig.DefaultDependencies = false;
              timerConfig = {
                OnActiveSec = "10";
                Unit = "initrd-reboot.service";
              };
              conflicts = [ "shutdown.target" ];
              before = [
                "timers.target"
                "shutdown.target"
              ];
            };
          };

          services = {
            initrd-reboot = {
              description = "Reboot device to avoid hang on emergency access";
              unitConfig.DefaultDependencies = false;
              serviceConfig = {
                Type = "oneshot";
                ExecStart = "systemctl reboot";
              };
            };
          }
          // lib.optionalAttrs cfg.notify.enable {
            luks-ready-notify = {
              description = "Email notification when LUKS unlock via SSH is ready";
              unitConfig.DefaultDependencies = false;
              after = [
                "network-online.target"
                "initrd-nixos-copy-secrets.service"
              ];
              before = [
                "sshd.service"
              ];
              wants = [
                "network-online.target"
                "initrd-nixos-copy-secrets.service"
              ];
              wantedBy = [ "sshd.service" ];

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
  };
}
