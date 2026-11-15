{
  inputs,
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.services.forgejo;
in
{
  options.${namespace}.services.forgejo = {
    enable = lib.mkEnableOption "Enable forgejo";
    mailer = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = "Enable mail functionality";
    };
    theme = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = "Enable theme override";
    };
    rootURL = lib.mkOption {
      type = lib.types.str;
      default = "git.${config.hostSpec.domain}";
      description = "Use a simplified domain as root, instead of git.<hostName>.<domain>";
    };
    appName = lib.mkOption {
      type = lib.types.str;
      default = "FidgetingGit";
      description = "";
    };
    appSlogan = lib.mkOption {
      type = lib.types.str;
      default = "Like lieutenant Dan we rollin'";
      description = "";
    };

    # NOTE: Forgejo doesn't allow creation of an account named "admin"
    adminUser = lib.mkOption {
      type = lib.types.str;
      default = config.hostSpec.primaryUsername;
      description = "";
    };
    adminEmail = lib.mkOption {
      type = lib.types.str;
      default = "admin@${config.hostSpec.domain}";
      description = "";
    };
  };
  config =
    let
      sopsFolder = (lib.toString inputs.nix-secrets) + "/sops";
      forgejoPort = config.hostSpec.networking.ports.tcp.forgejo;
      sshPort = config.hostSpec.networking.ports.tcp.ssh;

      firewallCfg = config.${namespace}.networking.granularFirewall;
      regularFirewallRules = lib.mkIf (firewallCfg.enable == false) {
        networking.firewall.allowedTCPPorts = [ forgejoPort ];
      };

      theme = pkgs.fetchzip {
        url = "https://github.com/catppuccin/gitea/releases/download/v1.0.2/catppuccin-gitea.tar.gz";
        sha256 = "sha256-rZHLORwLUfIFcB6K9yhrzr+UwdPNQVSadsw6rg8Q7gs=";
        stripRoot = false;
      };
    in
    lib.mkIf cfg.enable (
      lib.mkMerge [
        {
          # Using user git because introdus git-dev.nix is setup to default to git@ for forge auth over ssh
          users.groups.git = { };
          users.users.git = {
            isSystemUser = true;
            group = "git";
            home = config.services.forgejo.stateDir;
            useDefaultShell = true;
            # NOTE: authorized keys are handled by forgejo user management
          };

          # https://codeberg.org/forgejo/docs/src/commit/7b8397/docs/admin/config-cheat-sheet.md
          services.forgejo = {
            enable = true;
            package = pkgs.unstable.forgejo;
            user = "git";
            group = "git";
            # Enable support for Git Large File Storage
            lfs.enable = true;
            # Enable little mini-backups (FIXME: not sure if worth)
            dump = {
              enable = true;
            };
            settings = {
              server = {
                HTTP_ADDR = "127.0.0.1"; # Accessed via nginx proxy
                DOMAIN = config.hostSpec.domain;
                # You need to specify this to remove the port from URLs in the web UI.
                ROOT_URL = "https://${cfg.rootURL}/";
                HTTP_PORT = forgejoPort;
                DISABLE_SSH = false;
                SSH_PORT = sshPort;
              };
              DEFAULT = {
                APP_NAME = cfg.appName;
                APP_SLOGAN = cfg.appSlogan;
              };
              service.DISABLE_REGISTRATION = true;
              session.COOKIE_SECURE = true;

              actions = {
                ENABLED = true;
                DEFAULT_ACTIONS_URL = "github";
              };

              repository = {
                FORCE_PRIVATE = true;
              };
            }
            // lib.optionalAttrs cfg.mailer {
              mailer = {
                ENABLED = true;
                SMTP_ADDR = config.hostSpec.email.internalServer;
                PROTOCOL = "smtp+starttls";
                SMTP_PORT = 25; # NOTE: Running on ooze so using the local relay
                FROM = "noreply@${config.hostSpec.domain}";
                USER = config.hostSpec.hostName;
                SEND_AS_PLAIN_TEXT = true;
              };
            }
            // lib.optionalAttrs cfg.theme {
              ui = {
                THEMES =
                  theme
                  |> lib.readDir
                  |> lib.attrNames
                  |> map (name: lib.removePrefix "theme-" (lib.removeSuffix ".css" name))
                  |> lib.concatStringsSep ",";
                DEFAULT_THEME = "catppuccin-mocha-sapphire";
              };
            };
            secrets = {
              mailer = lib.optionalAttrs cfg.mailer {
                PASSWD = config.sops.secrets."passwords/postfix-relay".path;
              };
            };
          };
          # systemd.services.forgejo = {
          #   after = [ "postgresql-setup.service" ];
          #   requires = [ "postgresql-setup.service" ];
          # };

          # From nix wiki. Ensure user is setup
          systemd.services.forgejo.postStart =
            let
              forgejo = "${lib.getExe config.services.forgejo.package} --config ${config.services.forgejo.stateDir}/custom/conf/app.ini";
              passFile = config.sops.secrets."passwords/forgejo/admin".path;
              inherit (cfg) adminUser adminEmail;
            in
            # bash
            ''
              # Check if the user already exists
                if ! ${forgejo} admin user list | grep -q "${adminUser}"; then
                  echo "Creating Forgejo admin user..."
                  ${forgejo} admin user create \
                    --admin \
                    --username "${adminUser}" \
                    --email "${adminEmail}" \
                    --password "$(tr -d '\n' < ${passFile})"
                fi
            '';

          ${namespace}.services.nginxProxy.services = [
            {
              subDomain = "git"; # Creates git.host.domain
              extraDomains = [ cfg.rootURL ];
              port = forgejoPort;
              ssl = false;
            }
          ];

          # Need to allow authorize keys file use for this user to allow forgejo to manage it.
          # Normally these files are locked down to prevent priv esc by dropping a new key
          # See modules/hosts/nixos/openssh/default.nix for note
          services.openssh.extraConfig = ''
            Match User git
                AuthorizedKeysFile /var/lib/forgejo/.ssh/authorized_keys
          '';

          sops.secrets = {
            "passwords/forgejo/admin" = {
              sopsFile = "${sopsFolder}/${config.hostSpec.hostName}.yaml";
              owner = config.services.forgejo.user;
              inherit (config.services.forgejo) group;
            };
          };

          environment = lib.optionalAttrs config.introdus.impermanence.enable {
            persistence = {
              "${config.hostSpec.persistFolder}".directories = [
                {
                  directory = config.services.forgejo.stateDir;
                  inherit (config.services.forgejo) user group;
                  mode = "0700";
                }
              ];
            };
          };

          # Add custom themes/icons to forgejo instance
          systemd.tmpfiles.rules =
            let
              cfg = config.services.forgejo;
              img = "${inputs.nix-assets}/images/forgejo/";
            in
            [
              "d '${cfg.customDir}' 0750 ${cfg.user} ${cfg.group} - -"
              "d '${cfg.customDir}/public' 0750 ${cfg.user} ${cfg.group} - -"
              "d '${cfg.customDir}/public/assets' 0750 ${cfg.user} ${cfg.group} - -"
              "d '${cfg.customDir}/public/assets/img' 0750 ${cfg.user} ${cfg.group} - -"
              "L+ '${cfg.customDir}/public/assets/css' - - - - ${theme}"
              "L+ '${cfg.customDir}/public/assets/img/logo.svg' - - - - ${img}/logo.svg"
              "L+ '${cfg.customDir}/public/assets/img/logo.png' - - - - ${img}/logo.png"
              "L+ '${cfg.customDir}/public/assets/img/favicon.svg' - - - - ${img}/favicon.svg"
              "L+ '${cfg.customDir}/public/assets/img/favicon.png' - - - - ${img}/favicon.png"
            ];
        }
        regularFirewallRules
      ]
    );
}
