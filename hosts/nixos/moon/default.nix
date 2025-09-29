# Beelink EQR5
{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:
{
  imports = lib.flatten [
    inputs.adblock-hosts.nixosModule
    inputs.nixos-facter-modules.nixosModules.facter
    { config.facter.reportPath = ./facter.json; }
    (lib.custom.relativeToRoot "hosts/common/disks/btrfs-impermanence-disko.nix")
    {
      _module.args = {
        withSwap = true;
      };
    }

    (map lib.custom.relativeToRoot (
      [
        "hosts/common/core"
        "hosts/common/core/nixos.nix"
      ]
      ++
        # Optional common modules
        (map (f: "hosts/common/optional/${f}") [
          # Desktop environment and login manager
          "sddm.nix"
          "gnome.nix"

          # Services
          "services/openssh.nix"
          "services/ddclient.nix"

          # Network management
          "systemd-resolved.nix"

          # Misc
          "msmtp.nix"
          "plymouth.nix"
          "sound.nix"
          "cli.nix"
          # "yubikey.nix"
          "fonts.nix"
        ])
    ))
  ];

  # Host Specification
  hostSpec = {
    hostName = "moon";
    users = lib.mkForce [
      "admin"
      "ca"
    ];
    primaryUsername = lib.mkForce "admin";
    primaryDesktopUsername = lib.mkForce "ca";
    # FIXME: deprecate this
    username = lib.mkForce "admin";

    # System type flags
    isWork = lib.mkForce false;
    isProduction = lib.mkForce true;
    isRemote = lib.mkForce true;

    # Functionality
    voiceCoding = lib.mkForce false;
    # FIXME: Separate this out to allow yubikey for incoming auth but not physical yubikey plugged in
    useYubikey = lib.mkForce false;
    useNeovimTerminal = lib.mkForce true;
    useAtticCache = lib.mkForce false;

    # Networking
    wifi = lib.mkForce true;

    # Graphical
    defaultDesktop = "gnome";
    useWayland = lib.mkForce true;
    hdr = lib.mkForce true;
    scaling = lib.mkForce "2";
    isAutoStyled = lib.mkForce true;
    wallpaper = "${inputs.nix-assets}/images/wallpapers/botanical_garden.webp";
    persistFolder = lib.mkForce "/persist";
    timeZone = lib.mkForce "America/Edmonton";
  };

  system.impermanence.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  # Bootloader.
  boot.loader.systemd-boot = {
    enable = true;
    # When using plymouth, initrd can expand by a lot each time, so limit how many we keep around
    configurationLimit = lib.mkDefault 10;
    consoleMode = "1";
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;

  # We need IPv6 in order to access hetzner cloud systems
  networking.networkmanager.enable = true;
  networking.useDHCP = lib.mkDefault true;
  networking.dhcpcd.wait = "background";
  systemd.network.wait-online.enable = false;
  services.gnome.gnome-keyring.enable = true;

  # Keyring, required for auth even without gnome
  security.pam.services.sddm.enableGnomeKeyring = true;

  # Auto-login as regular user
  services.displayManager.autoLogin = {
    user = lib.mkForce "ca";
  };
  services.displayManager.sddm.autoLogin = {
    relogin = true;
  };

  # FIXME:
  # services.backup = {
  #   enable = true;
  #   borgBackupStartTime = "09:00:00";
  # };

  sops = {
    secrets = {
      "keys/ssh/ed25519" = {
        # User/group created by the autosshTunnel module
        owner = "autossh";
        group = "autossh";
        path = "/etc/ssh/id_ed25519";
      };
      "keys/ssh/ed25519_pub" = {
        owner = "autossh";
        group = "autossh";
        path = "/etc/ssh/id_ed25519.pub";
      };
    };
  };

  services.autosshTunnels.sessions = {
    freshcakes = {
      user = "tunnel";
      host = config.hostSpec.networking.hosts.freshcakes;
      port = 22;
      secretKey = "/etc/ssh/id_ed25519";
      tunnels = [
        {
          localPort = config.hostSpec.networking.ports.tcp.jellyfin;
          remotePort = config.hostSpec.networking.ports.tcp.jellyfin;
        }
      ];
    };
  };

  # Add ad-blocking to hosts file
  networking.stevenBlackHosts.enable = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = "23.05";
}
