# This is sets up two services. One that is used for remote machine learning
# and the primary immich server
{ config, lib, ... }:
let
  cfg = config.services.immichML;
  ports = config.hostSpec.networking.ports;
in
{
  # Extend the existing options
  options.services.immichML = {
    enable = lib.mkEnableOption "Enable Immich with Machine Learning";
    # For regular immich server
    remoteMachineLearningHost = lib.mkOption {
      type = lib.types.str;
    };
    # For immich machine-learning server
    isRemoteMachineLearningServer = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    immichServers = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [ ];
      description = "List of immich hosts allowed to access the machine learning service";
    };
  };
  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && !cfg.isRemoteMachineLearningServer) {
      services.immich =
        let
          mlPort = toString ports.tcp.immich-ml;
        in
        {
          enable = true;
          port = ports.tcp.immich;
          openFirewall = !config.networking.granularFirewall.enable;
          machine-learning = {
            enable = true;
            environment = {
              IMMICH_PORT = lib.mkForce (mlPort);
            };
          };

          settings = {
            # NOTE: ml hosts are tried in sequential order
            # https://docs.immich.app/guides/remote-machine-learning/
            machineLearning.urls = [
              "http://${cfg.remoteMachineLearningHost}:${mlPort}"
              "http://localhost:${mlPort}"
            ];
          };
        };

      services.nginxProxy.services = [
        {
          subDomain = "immich"; # Creates git.host.domain
          extraDomains = [ "photos.${config.hostSpec.domain}" ];
          port = ports.tcp.immich;
          ssl = false;
          # Extra stuff from the wiki
          extraLocationSettings = {
            proxyWebsockets = true;
            extraConfig = ''
              client_max_body_size 50000M;
              proxy_read_timeout   600s;
              proxy_send_timeout   600s;
              send_timeout         600s;
            '';
          };
        }
      ];

      # FIXME: This somehow breaks because of "opia" reference?
      networking.granularFirewall =
        let
          # FIXME: Make this an option
          hosts = lib.attrValues {
            inherit (config.hostSpec.networking.subnets.olan.hosts)
              oppo
              ossa
              # opia
              ;
          };
        in
        {
          # enable = true;
          allowedRules = [
            {
              serviceName = "immich";
              protocol = "tcp";
              ports = [ ports.tcp.immich ];
              inherit hosts;
            }
          ];
        };
    })

    (lib.mkIf cfg.isRemoteMachineLearningServer {
      services.immich = {
        enable = true;
        openFirewall = !config.networking.granularFirewall.enable;
        database.enable = false;
        redis.enable = false;
        machine-learning.environment = {
          IMMICH_HOST = lib.mkForce "0.0.0.0";
          IMMICH_PORT = lib.mkForce (toString ports.tcp.immich-ml);
        };
        accelerationDevices = null; # Grant access for hardware acceleration
      };
      # Only run the machine-learning portion
      systemd.services.immich-server = lib.mkForce { };

      networking.firewall.allowedTCPPorts = lib.optional (
        !config.networking.granularFirewall.enable
      ) ports.tcp.immich-ml;

      networking.granularFirewall = {
        enable = true;
        allowedRules = [
          {
            serviceName = "immich-ml";
            protocol = "tcp";
            ports = [ ports.tcp.immich-ml ];
            hosts = cfg.immichServers;
          }
        ];
      };

      environment = lib.optionalAttrs config.introdus.impermanence.enable {
        persistence = {
          "${config.hostSpec.persistFolder}".directories = [
            config.services.immich.machine-learning.environment.MACHINE_LEARNING_CACHE_FOLDER
          ];
        };
      };
    })

    (lib.mkIf cfg.enable {
      environment = lib.optionalAttrs config.introdus.impermanence.enable {
        persistence = {
          "${config.hostSpec.persistFolder}".directories = [ "/var/lib/immich" ];
        };
      };
      users.users.immich.extraGroups = lib.optionals (config.services.immich.accelerationDevices != [ ]) [
        "video"
        "render"
        "media"
      ];
    })
  ];
}
