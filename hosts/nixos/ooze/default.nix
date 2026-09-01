{
  inputs,
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  net = config.hostSpec.networking;
  wake-oppo = pkgs.writeShellApplication {
    name = "wake-oppo";
    runtimeInputs = [ pkgs.wakeonlan ];
    text =
      let
        oppo = net.subnets.o-lan.hosts.oppo;
      in
      "wakeonlan ${lib.elemAt oppo.mac 0} -i ${oppo.ip}";
  };
  olan = net.subnets.o-lan;
  wg-subnet = olan.wg-subnet;
in
{
  imports =
    lib.flatten [
      inputs.nixos-facter-modules.nixosModules.facter
      { config.facter.reportPath = ./facter.json; }
      (lib.custom.scanPaths ./.) # Auto-load all extra host-specific *.nix files
    ]
    ++ (map lib.custom.relativeToRoot (
      [
        ##
        # Core
        ##
        "hosts/common/core"
        "hosts/common/core/nixos.nix"
      ]
      ++
        # Optional common modules
        (map (f: "hosts/common/optional/${f}") [
          "keyd.nix"
          "services/atuin.nix"
          "services/atticd.nix" # Nix cache
          "services/postfix-proton-relay.nix"
          "services/unifi.nix" # Unifi Controller
          "services/forgejo.nix" # git forge
          "services/webdav.nix" # for grapheneos seedvault backups
          "services/calibre-web.nix" # ebook management
          "services/commafeed.nix" # rss reader
          "services/mattermost" # chat notifications
          # "services/nitter.nix" # ad-less twitter front-end
          "services/paperless.nix" # document management
          "services/hister.nix" # local document search
          "services/librechat.nix" # llm webui
          "services/searx.nix"

          "acme.nix"
          "remote-builder.nix"
        ])
    ));

  nixpkgs.config.nvidia.acceptLicense = true;

  services.backup = {
    enable = true;
    borgBackupStartTime = "*-*-* 05:00:00"; # Daily at 5am
  };

  # Conflicts with postfix
  programs.msmtp.setSendmail = lib.mkForce false;

  boot.initrd.availableKernelModules = [ "r8169" ];

  services.remoteLuksUnlock = {
    enable = true;
    unlockOnly = true;
    notify.to = config.hostSpec.email.olanAdmins;
  };

  services.dyndns = {
    enable = true;
    subDomains = [
      "ogre"
      "ooze"
      "vpn"
    ];
  };

  services.docuseal.enable = true; # Settings in module

  # FIXME: This could be swapped with monit now I think
  services.heartbeat-check = {
    enable = true;
    interval = 10 * 60;
    # FIXME: This should be updated to use host attr sets now
    hosts = [
      "ottr"
      "ogre"
      "oedo"
      "otto"
      "oath"
      "onus"
    ];
  };

  # Serial cables into lab systems
  # Two of these devices have identical serials, so we need to use the kernel path
  # https://askubuntu.com/questions/49910/how-to-distinguish-between-identical-usb-to-serial-adapters
  # WARNING: If you re-plug the cables, this may break
  services.udev.extraRules = ''
    # ttyUSB0
    ACTION=="add", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="A50285BI", KERNELS=="1-8.1", SYMLINK+="ttyUSB-fang"
    # ttyUSB1
    ACTION=="add", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="A9RAUGOI", SYMLINK+="ttyUSB-flux"
    # ttyUSB2
    ACTION=="add", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="A50285BI", KERNELS=="1-8.3", SYMLINK+="ttyUSB-frog"
    # ttyUSB3
    ACTION=="add", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="A9IPH6E8", SYMLINK+="ttyUSB-frby"
  '';

  environment.systemPackages = [
    wake-oppo
  ];

  ${namespace} = {
    wireguard = {
      enable = true;
      role = "server";
      externalInterface = "enp3s0";
      peers = [
        wg-subnet.hosts.ossa
        wg-subnet.hosts.opia
        wg-subnet.hosts.moon
      ];
      wireguardPort = net.ports.udp.wireguard;
      rosenpassPort = net.ports.udp.rosenpass;
      rosenpassExempt = [
        "opia"
        "moxy"
      ];
      subnet = wg-subnet;
    };
  };

  # Extra peers not on o-lan subnet that can't be auto-generated
  networking = {
    useDHCP = lib.mkDefault true;
    # FIXME: Not sure why I have to manually do this on ooze and not oppo
    nameservers = [ config.hostSpec.networking.subnets.o-lan.gateway ];
    search = [ "${config.hostSpec.domain}" ];

    wireguard.interfaces.${config.${namespace}.wireguard.interface}.peers =
      let
        inherit (lib.custom.network) mkWireguardPeer;
      in
      [
        (mkWireguardPeer wg-subnet.hosts.moon)
        (mkWireguardPeer wg-subnet.hosts.moxy)
      ];

    nftables =
      let
        oozeIP = "${wg-subnet.hosts.ooze.ip}/32";
        iif = "wg0";
      in
      {
        enable = true;
        ruleset =
          let
            moonIP = wg-subnet.hosts.moon.ip;
          in
          ''
            table inet moon_lan_routing {
              chain input {
                type filter hook input priority -10; policy accept;
                iifname "${iif}" ip saddr ${moonIP} ct state vmap { established : accept, related : accept };
                iifname "${iif}" ip saddr ${moonIP} ip daddr ${oozeIP} tcp dport ${toString net.ports.tcp.nginx} accept;
                # iifname "${iif}" ip saddr ${moonIP} icmp type echo-request accept;
                iifname "${iif}" ip saddr ${moonIP} log prefix "WG MOON DROP" drop;
              }
              chain forward {
                type filter hook forward priority -10; policy accept;
                iifname "wg0" ip saddr ${moonIP} ip daddr ${oozeIP} accept
                iifname "${iif}" ip saddr ${moonIP} log prefix "WG MOON DROP" drop;
              }
            }
          '';
      };
  };

  # Enable immich service with ML offload to oedo
  services.immichML = {
    enable = true;
    remoteMachineLearningHost = "oedo.${config.hostSpec.domain}";
  };

  services.nginxProxy = {
    defaultAllowList = [
      olan.cidr
      olan.wg-subnet.hosts.ossa.ip
      olan.wg-subnet.hosts.onyx.ip
      olan.wg-subnet.hosts.opia.ip
    ];
    defaultDenyList = [ "all" ];
  };

  services.nginx.virtualHosts."photos.${config.hostSpec.domain}".locations."/".extraConfig =
    lib.mkBefore ''
      allow ${olan.wg-subnet.hosts.moon.ip};
      allow ${olan.wg-subnet.hosts.moxy.ip};
    '';
}
