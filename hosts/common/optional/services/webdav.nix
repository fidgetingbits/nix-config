# webdav server for graphene (seedvault) backups
{
  config,
  lib,
  ...
}:
let
  servicePort = config.hostSpec.networking.ports.tcp.webdav;
in
{

  sops.secrets."passwords/webdav" = {
    owner = "webdav";
    group = "webdav";
  };

  services.webdav-server-rs = {
    enable = true;
    # debug = true;
    settings = {
      server.listen = [
        "0.0.0.0:${toString servicePort}"
      ];
      accounts = {
        auth-type = "htpasswd.default";
        acct-type = "unix";
      };
      # `nix shell nixpkgs#apacheHttpd`
      # `htpasswd -B -c ./htpasswd <username>`
      htpasswd.default = {
        htpasswd = config.sops.secrets."passwords/webdav".path;
      };
      location = [
        {
          route = [ "/*path" ];
          directory = "/var/lib/webdav";
          handler = "filesystem";
          methods = [ "webdav-rw" ];
          autoindex = true;
          auth = "true";
        }
      ];
    };
  };

  services.nginxProxy.services = [
    {
      subDomain = "webdav";
      port = servicePort;
      ssl = false;
    }
  ];

  environment = lib.optionalAttrs config.introdus.impermanence.enable {
    persistence = {
      "${config.hostSpec.persistFolder}".directories = [
        {
          directory = "/var/lib/webdav";
          user = "webdav";
          group = "webdav";
          mode = "u=rwx,g=rwx,o=";
        }
      ];
    };
  };
}
