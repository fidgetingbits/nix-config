{
  inputs,
  lib,
  config,
  namespace,
  ...
}:
let
  time = lib.custom.time;
  homeDirectory = config.hostSpec.home;
  firewallCfg = config.networking.granularFirewall;

  desktops = [
    "onyx"
    "oedo"
  ];
  mobiles = [
    "opia"
  ];
  devices = desktops ++ mobiles;
  deviceIds =
    devices
    |> lib.map (device: {
      ${device}.id = inputs.nix-secrets.syncthing.${device};
    })
    |> lib.attrsets.mergeAttrsList;

  hosts = lib.map (d: inputs.nix-secrets.networking.subnets.ogre.hosts.${d}) devices;

  # Syncthing ports: 8384 for remote access to GUI
  # 22000 TCP and/or UDP for sync traffic
  # 21027/UDP for discovery
  # source: https://docs.syncthing.net/users/firewall.html
  ports = config.hostSpec.networking.ports;

  granularFirewallRules = lib.mkIf firewallCfg.enable {
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
  regularFirewallRules = lib.mkIf (firewallCfg.enable == false) {
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
        dataDir = "${homeDirectory}/sync/"; # synced folders
        configDir = "${homeDirectory}/.config/syncthing"; # settings and keys
        guiAddress = "127.0.0.1:${builtins.toString ports.tcp.syncthing.gui}";
        relay.enable = false; # Don't start the local relay service

        settings = {
          options = {
            # localAnnounceEnabled = false;
            urAccepted = -1; # Don't send anonymous stats
            # Don't use public relay. Change this if we setup our own
            relaysEnabled = false;
          };
          devices = deviceIds;

          folders =
            let
              # See https://wes.today/nixos-syncthing/
              versioning = {
                type = "staggered";
                params = {
                  cleanInterval = "${toString (time.hours 1)}";
                  maxAge = "${toString (time.days 180)}";
                };
              };
            in
            {
              images = {
                path = "${homeDirectory}/images/";
                devices = desktops;
                inherit versioning;
              };
              wiki = {
                path = "${homeDirectory}/wiki/";
                devices = desktops ++ mobiles;
                inherit versioning;
              };
              scripts = {
                path = "${homeDirectory}/scripts/";
                devices = desktops;
                inherit versioning;
              };
            };
        };
      };
    };
    ${namespace}.services.per-network-services.trustedNetworkServices = [ "syncthing" ];
  }
  granularFirewallRules
  regularFirewallRules
]
