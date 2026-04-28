{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [ ./nginx.nix ];
  config =
    let
      # FIXME: This is duplicated with hosts/common/users/default.nix so could probably make ti a lib
      # Generate a list of public key contents to use by ssh
      genPubKeyList =
        user:
        let
          keyPath = (lib.custom.relativeToRoot "hosts/common/users/${user}/keys/");
        in
        if (lib.pathExists keyPath) then
          lib.lists.forEach (lib.filesystem.listFilesRecursive keyPath) (key: lib.readFile key)
        else
          [ ];

      # List of yubikey public keys that will allow auth to any user, across systems
      superPubKeys = genPubKeyList "super";
      sopsFolder = (builtins.toString inputs.nix-secrets) + "/sops";
      forgejoPort = config.hostSpec.networking.ports.tcp.forgejo;
      sshPort = config.hostSpec.networking.ports.tcp.ssh;

      cfg = config.networking.granularFirewall;
      granularFirewallRules = lib.mkIf cfg.enable {
        networking.granularFirewall.allowedRules = [
          {
            serviceName = "forgejo";
            protocol = "tcp";
            ports = [ forgejoPort ];
            hosts = config.hostSpec.networking.rules.${config.hostSpec.hostName}.forgejoAllowedHosts;
          }
        ];
      };
      regularFirewallRules = lib.mkIf (cfg.enable == false) {
        networking.firewall.allowedTCPPorts = [ forgejoPort ];
      };
    in
    lib.mkMerge [
      {
        # Using user git because introuds git-dev.nix is setup to default to git@ for forge auth over ssh
        users.groups.git = { };
        users.users.git = {
          isSystemUser = true;
          useDefaultShell = true;
          group = "git";
          home = config.services.forgejo.stateDir;
          openssh.authorizedKeys.keys = superPubKeys;
        };

        # https://codeberg.org/forgejo/docs/src/commit/7b8397/docs/admin/config-cheat-sheet.md
        services.forgejo = {
          enable = true;
          package = pkgs.unstable.forgejo;
          user = "git";
          group = "git";
          # Enable support for Git Large File Storage
          lfs.enable = true;

          settings = {
            server = {
              HTTP_ADDR = "127.0.0.1"; # Accessed via nginx proxy
              DOMAIN = config.hostSpec.domain;
              # You need to specify this to remove the port from URLs in the web UI.
              ROOT_URL = "https://git.${config.hostSpec.hostName}.${config.hostSpec.domain}/";
              HTTP_PORT = forgejoPort;
              SSH_PORT = sshPort;
            };
            DEFAULT = {
              APP_NAME = "FidgetingGit";
              APP_SLOGAN = "Like lieutenant Dan we rollin'";
            };
            service.DISABLE_REGISTRATION = false;
            session.COOKIE_SECURE = true;

            # repository = {
            #   DISABLE_HTTP_GIT = false;
            # };
            actions = {
              ENABLED = true;
              DEFAULT_ACTIONS_URL = "github";
            };
            mailer = {
              ENABLED = true;
              SMTP_ADDR = config.hostSpec.email.internalServer;
              PROTOCOL = "smtp+starttls";
              SMPT_PORT = 25; # FIXME: Running on ooze so using the local relay, but likely should optional
              FROM = "noreply@${config.hostSpec.domain}";
              USER = config.hostSpec.hostName;
              SEND_AS_PLAIN_TEXT = true;
            };
          };
          secrets = {
            mailer.PASSWD = config.sops.secrets."passwords/postfix-relay".path;
          };
        };
        systemd.services.forgejo = {
          after = [ "postgresql-setup.service" ];
          requires = [ "postgresql-setup.service" ];
        };

        # From nix wiki. Ensure user is setup
        systemd.services.forgejo.postStart =
          let
            forgejo = "${lib.getExe config.services.forgejo.package} admin user";
            passFile = config.sops.secrets."passwords/forgejo/admin".path;
            adminUser = config.hostSpec.primaryUsername; # NOTE: Forgejo doesn't allow creation of an account named "admin"
            adminEmail = "admin@${config.hostSpec.domain}";
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

        services.nginxProxy.services = [
          {
            subDomain = "git";
            port = forgejoPort;
            ssl = false;
          }
        ];

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
      }
      granularFirewallRules
      regularFirewallRules
    ];
}
