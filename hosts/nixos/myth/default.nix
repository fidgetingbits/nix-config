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
          # "msmtp.nix" # FIXME: We only need this if we setup emails for logins/backups, etc
          "cli.nix"
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
    isAutoStyled = lib.mkForce false;
    useWindowManager = lib.mkForce false;

    # Functionality
    voiceCoding = lib.mkForce false;
    useYubikey = lib.mkForce false;
    useNeovimTerminal = lib.mkForce false;
    useAtticCache = lib.mkForce false;

    # Networking
    wifi = lib.mkForce false;

    # Sysystem settings
    persistFolder = lib.mkForce "/persist";
    timeZone = lib.mkForce "America/Edmonton";
  };

  system.impermanence.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  # Bootloader
  boot.loader.systemd-boot = {
    enable = true;
    # Needs to be lowered if we ever run plymouth
    configurationLimit = lib.mkDefault 30;
    consoleMode = "1";
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # Note using wifi on this box for now
  boot.blacklistedKernelModules = [
    "iwlwifi"
  ];
  systemd.network.netdevs.wlo1.enable = false;

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

  # FIXME: This may be better as part of a module or just in the host-specific file
  # triggered auto scan of raid5 drives during nixos-anywhere install
  systemd.services."mdmonitor".environment = {
    MDADM_MONITOR_ARGS = "--scan --syslog";
  };

  # needed to unlock LUKS on raid drives
  # use partition UUID
  # https://wiki.nixos.org/wiki/Full_Disk_Encryption#Unlocking_secondary_drives
  environment.etc.crypttab.text = lib.optionalString (!config.hostSpec.isMinimal) ''
    encrypted-backup UUID=25541f69-ee5f-4e2d-8939-2b4f1643fe90 /luks-secondary-unlock.key
  '';

  # FIXME:
  # services.backup = {
  #   enable = true;
  #   borgBackupStartTime = "09:00:00";
  # };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = "23.05";
}
