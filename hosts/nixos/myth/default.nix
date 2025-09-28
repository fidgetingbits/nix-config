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
    inputs.nixos-facter-modules.nixosModules.facter
    { config.facter.reportPath = ./facter.json; }
    ./disko.nix

    (map lib.custom.relativeToRoot (
      [
        "hosts/common/core"
        "hosts/common/core/nixos.nix"
      ]
      ++
        # Optional common modules
        (map (f: "hosts/common/optional/${f}") [
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
          "fonts.nix"
        ])
    ))
  ];

  # Host Specification
  hostSpec = {
    hostName = "myth";
    users = lib.mkForce [
      "admin"
      "pa"
    ];
    primaryUsername = lib.mkForce "admin";
    # FIXME: deprecate this
    username = lib.mkForce "admin";

    # System type flags
    isWork = lib.mkForce false;
    isProduction = lib.mkForce true;
    isRemote = lib.mkForce true;
    isServer = lib.mkForce true;
    # FIXME: Disable this, but breaks builds otherwise fo rnow
    isAutoStyled = lib.mkForce true;
    useWindowManager = lib.mkForce true;

    # Functionality
    voiceCoding = lib.mkForce false;
    useYubikey = lib.mkForce false;
    useNeovimTerminal = lib.mkForce true;
    useAtticCache = lib.mkForce false;

    # Networking
    wifi = lib.mkForce true;

    # Sysystem settings
    persistFolder = lib.mkForce "/persist";
    timeZone = lib.mkForce "America/Edmonton";
  };

  system.impermanence.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  # Bootloader
  boot.loader.systemd-boot = {
    enable = true;
    # When using plymouth, initrd can expand by a lot each time, so limit how many we keep around
    configurationLimit = lib.mkDefault 10;
    consoleMode = "1";
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # Remote early boot LUKS unlock via ssh
  boot.initrd = {
    systemd = {
      enable = true;
      # emergencyAccess = true;
      users.root.shell = "/bin/systemd-tty-ask-password-agent";
    };
    luks.forceLuksSupportInInitrd = true;
    # Setup the host key as a secret in initrd, so it's not exposed in the /nix/store
    # this is all too earlier for sops
    secrets = lib.mkForce { "/etc/secrets/initrd/ssh_host_ed25519_key" = ./initrd_ed25519_key; };
    network = {
      enable = true;
      ssh = {
        enable = true;
        port = config.hostSpec.networking.ports.tcp.ssh;
        authorizedKeys = config.users.users.${config.hostSpec.username}.openssh.authorizedKeys.keys;
        hostKeys = [ "/etc/secrets/initrd/ssh_host_ed25519_key" ];
      };
    };
  };

  # needed to unlock LUKS on raid drives
  # use partition UUID
  # https://wiki.nixos.org/wiki/Full_Disk_Encryption#Unlocking_secondary_drives
  environment.etc.crypttab.text = lib.optionalString (!config.hostSpec.isMinimal) ''
    encrypted-backup UUID=TBD /luks-secondary-unlock.key
  '';

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

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = "23.05";
}
