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
    ./disks.nix

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

          # Network management
          "systemd-resolved.nix"

          # Misc
          "mail.nix"
          "logind.nix"
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
      "borg"
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

  environment.systemPackages = [ pkgs.borgbackup ];
  # Bootloader
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = lib.mkDefault 8; # NOTE: 10 ran out of disk space
    consoleMode = "1";
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # wlo1 boot delay
  #
  # FIXME: I removed wlo1 entirely from facter.json since the below didn't work,
  # but leaving it in. See facter.json.wlo1.bk for old version (or regenerate).
  #
  # Add neededForBoot = false to stop the 1m30s wait on startup once
  # https://github.com/NixOS/nixpkgs/pull/360092 is finalized
  #
  # None of these work to stop the 1m30s delay on boot, but leaving for reference
  # boot.blacklistedKernelModules = [
  #   "iwlwifi"
  # ];
  # networking.interfaces.wlo1.useDHCP = false;
  # systemd.network.netdevs.wlo1.enable = false;

  services.remoteLuksUnlock = {
    enable = true;
    notify.to = config.hostSpec.email.mythAdmins;
  };
  services.logind.powerKey = lib.mkForce "reboot";
  services.dyndns.enable = true;

  systemd = {
    tmpfiles.rules =
      let
        name = user: config.users.users.${user}.name;
        group = user: config.users.users.${user}.group;
      in
      [
        "d /mnt/storage/backup/ 0750 ${name "borg"} ${group "borg"} -"
        "d /mnt/storage/backup/pa 0700 ${name "pa"} ${group "pa"} -"
      ];
  };

  # FIXME:
  # services.backup = {
  #   enable = true;
  #   borgBackupStartTime = "09:00:00";
  # };

  # Connect our NUT client to the UPS on the network
  services.ups = {
    client.enable = true;
    name = "ups";
    username = "monuser";
    ip = config.hostSpec.networking.subnets.myth.hosts.synology.ip;
    powerDownTimeOut = (60 * 30); # 30m. UPS reports ~45min
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = "23.05";
}
