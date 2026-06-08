{
  config,
  lib,
  pkgs,
  ...
}:
let
  servicePort = config.hostSpec.networking.ports.tcp.mattermost;
  dbUri = "postgres://mattermost@/mattermost?host=/run/postgresql/";

  mmEnvFile = pkgs.writeText "mattermost-env" ''
    MM_SQLSETTINGS_DRIVERNAME=postgres
    MM_SQLSETTINGS_DATASOURCE=${dbUri}
  '';

in
{
  # Hacks for pfsense slack notifications in mattermost
  imports = [ ./pfsense-slack.nix ];

  services.mattermost = {
    enable = true;
    siteUrl = "https://chat.${config.hostSpec.domain}";
    siteName = "Fidgeting Chat";
    port = servicePort;
    database = {
      fromEnvironment = true;
      create = false;
      peerAuth = true;
    };
    mutableConfig = true; # FIXME: use mutable for testing stuff
    preferNixConfig = true;
    environmentFile = "${mmEnvFile}";

    # Reference: https://docs.mattermost.com/configure/configuration-settings.html
    settings = {
      TeamSettings = {
        EnableAccountCreation = false; # Only shut this off after creating your first user
        EnableOpenServer = false;
      };
      ServiceSettings = {
        EnableBotAccountCreation = true;
      };
    };
  };

  services.nginxProxy.services = [
    {
      subDomain = "chat"; # Creates chat.host.domain
      extraDomains = [
        "chat.${config.hostSpec.domain}"
      ];
      port = servicePort;
      ssl = false;
      extraLocationSettings = {
        proxyWebsockets = true;
      };
    }
  ];

  # NOTE: mattermost tmpfile creation seems to be incompatible with impermanence for some reason? I guess maybe it
  # runs before the impermanence mount, so the created files get hidden? This forces the tmpfile rules to run
  # right before launch, to ensure that they land inside the persistence mount
  # IMPORTANT: You _might_ need to manually run `systemd-tmpfiles --create --prefix=/var/lib/mattermost` once, if
  # your /var/lib/mattermost folder is still empty after the service starts. Just restart it after
  # FIXME: Would be nice to fix this somehow in nixpkgs and PR, maybe by not using systemd.tmpfiles for these folders?
  systemd.services.mattermost = {
    serviceConfig = {
      ExecStartPre = "${pkgs.systemd}/bin/systemd-tmpfiles --create --prefix=/var/lib/mattermost";
    };
  };

  environment = lib.optionalAttrs config.introdus.impermanence.enable {
    persistence = {
      "${config.hostSpec.persistFolder}".directories = [
        {
          directory = "/var/lib/mattermost";
          inherit (config.services.mattermost) user group;
          mode = "0750";
        }
      ];
    };
  };
}
