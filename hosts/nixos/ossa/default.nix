{
  inputs,
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
{
  imports = lib.flatten [
    inputs.nixos-hardware.nixosModules.framework-16-amd-ai-300-series
    inputs.nixos-facter-modules.nixosModules.facter
    { config.facter.reportPath = ./facter.json; }
    (lib.custom.scanPaths ./.) # Load all extra host-specific *.nix files

    (map lib.custom.relativeToRoot (
      [
        "hosts/common/core"
        "hosts/common/core/nixos.nix"
      ]
      ++
        # Optional common modules
        (map (f: "hosts/common/optional/${f}") [
          # Host-specific stuff
          "keyd.nix"
          "plymouth.nix"
          "printing.nix"
          "locale.nix"
          "sound.nix"
          # FIXME: Rename this
          "mail-delivery.nix"

          # Desktop environment and login manager
          "sddm.nix"
          "niri.nix"

          # Miscellaneous
          "podman.nix"
          "libvirt.nix"
          "wireshark.nix"
          "cli.nix"
          "yubikey.nix"
          #"iphone-backup.nix"

          # Binary analysis tools
          # "binaryninja.nix"
          # FIXME: Temporary to work around build error on update
          #"cynthion.nix"
          "saleae.nix"

          # Network management
          "systemd-resolved.nix"

          # Remote network mounts and syncing
          "services/syncthing.nix"

          # "startpage.nix"

          # Gaming
          "gaming.nix"

          "distributed-builds.nix"
          "fonts.nix"

          "logind.nix"
        ])
    ))
  ];

  wifi = {
    enable = true;
    roaming = config.hostSpec.isRoaming;
  };

  # Just set the console font, don't mess with the font settings
  #console.font = lib.mkDefault "${pkgs.terminus_font}/share/consolefonts/ter-v32n.psf.gz";
  console.earlySetup = lib.mkDefault true;

  # Enable swap on luks
  boot.initrd.systemd.enable = true;
  boot.supportedFilesystems = [ "ntfs" ];

  # Keyring, required for auth even without gnome
  # FIXME: double check this
  security.pam.services.sddm.enableGnomeKeyring = true;
  modules.hardware.radeon.enable = true;

  environment.systemPackages = lib.attrValues {
    inherit (pkgs)
      # gnupg - see yubikey.nix
      paperkey # printed gpg key backup utilitie
      pinentry-curses # for gpg-agent
      pinentry-gtk2 # for gpg-agent

      fw-ectool # FW16 fan speed, charge limit
      ;
  };
  services.fwupd.enable = true;
  services.backup = {
    enable = true;
    borgBackupStartTime = "*-*-* 03:00:00";
  };

  services.remoteLuksUnlock = {
    enable = true;
    notify.to = config.hostSpec.email.olanAdmins;
  };
  system.impermanence.enable = true;

  #  virtualisation.appvm = {
  #    enable = true;
  #    user = config.hostSpec.primaryUsername;
  #  };

  # Bluetooth
  services.blueman.enable = true;

  # FIXME: Move this to a ccache module
  programs.ccache.enable = true;
  nix.settings.extra-sandbox-paths = [ config.programs.ccache.cacheDir ];
  environment.persistence.${config.hostSpec.persistFolder}.directories =
    lib.mkIf config.system.impermanence.enable
      [
        # CCache
        (lib.mkIf config.programs.ccache.enable {
          directory = config.programs.ccache.cacheDir;
          user = "root";
          group = "nixbld";
          mode = "u=,g=rwx,o=";
        })
      ];

  # From here:
  # https://community.frame.work/t/no-sound-from-speaker-but-audio-expansion-module-and-bluetooth-headphones-works-how-to-troubleshoot/79259/4
  # Not sure if it's because of facter.json or what but, speaker wasn't set to default. pavucontrol
  # and wpctl status showed tons of Ryzen HD Audio entries, but no speaker sound would work. After
  # enabling/unmuting HiFi (Mic1, Mic2, Speaker) via alsamixer, the problem went away, and the entries in
  # pavucontrol/noctalia are now sane.
  services.pipewire.wireplumber = {
    enable = true;
    extraConfig.speakerProfile = {
      "monitor.alsa.rules" = [
        {
          matches = [ { "device.name" = "alsa_card.pci-0000_c1_00.6"; } ];
          actions = {
            "update-props" = {
              "device.profile" = "HiFi (Mic1, Mic2, Speaker)";
            };
          };
        }
      ];
    };
  };

  ${namespace}.wireguard =
    let
      net = config.hostSpec.networking;
      inherit (config.hostSpec) domain;
    in
    {
      enable = true;
      role = "client";
      peerNames = [ "ooze" ];
      allowedIPs = [
        net.wireguard.olan.subnet
        net.subnets.olan.cidr
      ];
      hosts = net.subnets.olan.hosts;
      endpoint = "vpn.${domain}";
      wireguardPort = net.ports.udp.wireguard;
      rosenpassPort = net.ports.udp.rosenpass;
      subnet = net.wireguard.olan.subnet;
      dns = {
        enable = true;
        server = net.subnets.olan.hosts.ogre.ip;
        inherit domain;
      };
    };
}
