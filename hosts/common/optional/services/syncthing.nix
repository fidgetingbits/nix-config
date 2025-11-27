# NOTE: There is no way to actually set your own device id in Syncthing as it's derived from the .pem files
# so the list need to get updated if the configurations can't be restored from backup...
{
  inputs,
  lib,
  config,
  ...
}:
let
  homeDirectory = config.hostSpec.home;

  desktops = [
    "onyx"
    "oedo"
    # "okra"
  ];
  mobiles = [
    "opia"
    "opal"
  ];
  deviceList = [
    "onyx"
    "oedo"
    "opal"
    "opia"
    # "okra"
  ];
  deviceIds = lib.attrsets.mergeAttrsList (
    builtins.map (device: { ${device}.id = inputs.nix-secrets.syncthing.${device}; }) deviceList
  );

  cfg = config.networking.granularFirewall;

  hosts = builtins.attrValues {
    inherit (inputs.nix-secrets.networking.subnets.ogre.hosts)
      oedo
      oryx
      opia
      opal
      ;
  };
  # Syncthing ports: 8384 for remote access to GUI
  # 22000 TCP and/or UDP for sync traffic
  # 21027/UDP for discovery
  # source: https://docs.syncthing.net/users/firewall.html
  ports = config.hostSpec.networking.ports;
  granularFirewallRules = lib.mkIf cfg.enable {
    networking.granularFirewall.allowedRules = [
      {
        serviceName = "syncthing";
        protocol = "tcp";
        ports = [ ports.tcp.syncthing.sync ];
        inherit hosts;
      }
      {
        serviceName = "syncthing";
        protocol = "udp";
        ports = [
          ports.udp.syncthing.sync
          ports.udp.syncthing.discovery
        ];
        inherit hosts;
      }
    ];
  };
  regularFirewallRules = lib.mkIf (cfg.enable == false) {
    networking.firewall.allowedTCPPorts = [ ports.tcp.syncthing.sync ];
    networking.firewall.allowedUDPPorts = [
      ports.udp.syncthing.sync
      ports.udp.syncthing.discovery
    ];
  };
in
lib.mkMerge [
  {
    services = {
      syncthing = {
        enable = true;
        user = config.hostSpec.username;
        # inherit (config.users.users.${config.hostSpec.username}) group;
        overrideDevices = true;
        overrideFolders = true;
        dataDir = "${homeDirectory}/sync/"; # Default folder for new synced folders
        configDir = "${homeDirectory}/.config/syncthing"; # Folder for Syncthing's settings and keys
        guiAddress = "127.0.0.1:${builtins.toString ports.tcp.syncthing.gui}";

        settings = {
          options = {
            localAnnounceEnabled = false;
            urAccepted = -1; # Don't send anonymous stats
          };
          devices = deviceIds;

          folders = {
            images = {
              #id = "u5gmt-htjya";
              path = "${homeDirectory}/images";
              devices = desktops;

              # See https://wes.today/nixos-syncthing/
              versioning = {
                type = "staggered";
                params = {
                  cleanInterval = "3600"; # 1 hour in seconds
                  maxAge = "15552000"; # 180 days in seconds
                };
              };
            };
            wiki = {
              #id = "u5gmt-htjya";
              path = "${homeDirectory}/wiki/";
              devices = desktops ++ mobiles;

              # See https://wes.today/nixos-syncthing/
              versioning = {
                type = "staggered";
                params = {
                  cleanInterval = "3600"; # 1 hour in seconds
                  maxAge = "15552000"; # 180 days in seconds
                };
              };
            };
            scripts = {
              #id = "u5gmt-htjya";
              path = "${homeDirectory}/scripts/";
              devices = desktops;

              # See https://wes.today/nixos-syncthing/
              versioning = {
                type = "staggered";
                params = {
                  cleanInterval = "3600"; # 1 hour in seconds
                  maxAge = "15552000"; # 180 days in seconds
                };
              };
            };
          };
        };
      };
    };

    services.per-network-services.trustedNetworkServices = [ "syncthing" ];

  }
  granularFirewallRules
  regularFirewallRules
]
