{
  inputs,
  config,
  lib,
  ...
}:
{
  imports = [ ./nginx.nix ];
  config =
    let
      sopsFolder = (builtins.toString inputs.nix-secrets) + "/sops";
      atticPort = config.hostSpec.networking.ports.tcp.atticd;
    in
    {
      sops.secrets = {
        "tokens/attic" = {
          sopsFile = "${sopsFolder}/${config.hostSpec.hostName}.yaml";
          path = "/etc/atticd.env";
        };
      };

      # Exposed via nginx virtualhost
      services.atticd = {
        enable = true;

        # Replace with absolute path to your credentials file
        environmentFile = config.sops.secrets."tokens/attic".path;

        settings = {
          listen = "127.0.0.1:${builtins.toString atticPort}";
          # FIXME: revisit this
          garbage-collection = {
            interval = "5 days";
            default-retention-period = "6 months";
          };
          compression = {
            type = "zstd";
          };
          # Data chunking
          #
          # Warning: If you change any of the values here, it will be
          # difficult to reuse existing chunks for newly-uploaded NARs
          # since the cutpoints will be different. As a result, the
          # deduplication ratio will suffer for a while after the change.
          chunking = {
            # The minimum NAR size to trigger chunking
            #
            # If 0, chunking is disabled entirely for newly-uploaded NARs.
            # If 1, all NARs are chunked.
            nar-size-threshold = 64 * 1024; # 64 KiB

            # The preferred minimum size of a chunk, in bytes
            min-size = 16 * 1024; # 16 KiB

            # The preferred average size of a chunk, in bytes
            avg-size = 64 * 1024; # 64 KiB

            # The preferred maximum size of a chunk, in bytes
            max-size = 256 * 1024; # 256 KiB
          };
        };
      };

      environment = lib.optionalAttrs config.system.impermanence.enable {
        persistence = {
          "${config.hostSpec.persistFolder}".directories = [
            {
              # NOTE: systemd Dynamic User requires /var/lib/private to be 0700. See impermanence module
              directory = "/var/lib/private/atticd";
              user = "nobody";
              group = "nogroup";
            }
          ];
        };
      };

      services.nginxProxy.services = [
        {
          subDomain = "atticd";
          port = atticPort;
          ssl = false;
          # Avoids 413 Request Entity Too Large
          extraConfig = {
            extraConfig = "client_max_body_size 0;";
          };
        }
      ];
    };
}
