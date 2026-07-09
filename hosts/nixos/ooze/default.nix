{
  inputs,
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  wake-oppo = pkgs.writeShellApplication {
    name = "wake-oppo";
    runtimeInputs = [ pkgs.wakeonlan ];
    text =
      let
        oppo = config.hostSpec.networking.subnets.o-lan.hosts.oppo;
      in
      "wakeonlan ${lib.elemAt oppo.mac 0} -i ${oppo.ip}";
  };

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
          "cli.nix"
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

  # If we setup postfix, this conflicts
  programs.msmtp.setSendmail = lib.mkForce false;

  boot.initrd.availableKernelModules = [ "r8169" ];

  # Allow remote luks unlock over ssh and email admins when the system is ready
  # to unlock
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

  # FIXME: I think this is generic elsewhere?
  networking.useDHCP = lib.mkDefault true;
  # FIXME: Not sure why I have to manually do this on ooze and not oppo
  networking.nameservers = [ config.hostSpec.networking.subnets.o-lan.gateway ];
  networking.search = [ "${config.hostSpec.domain}" ];

  ${namespace} = {
    wireguard =
      let
        net = config.hostSpec.networking;
      in
      {
        enable = true;
        role = "server";
        externalInterface = "enp3s0";
        peerNames = [
          "ossa"
          "opia"
        ];
        hosts = net.subnets.o-lan.hosts;
        wireguardPort = net.ports.udp.wireguard;
        rosenpassPort = net.ports.udp.rosenpass;
        rosenpassExempt = [ "opia" ];
        # FIXME: this wireguard thing should possibly be it's own subnet rather than a sub-subnet of o-lan? get's confusing with other wireguard networks
        subnet = net.subnets.o-lan.wireguard.subnet;
      };
  };

  # This enables immich service with ML offload to oedo
  services.immichML = {
    enable = true;
    remoteMachineLearningHost = "oedo.${config.hostSpec.domain}";
  };
}
