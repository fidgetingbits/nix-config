# model
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
    hostName = "moth";
    users = lib.mkForce [
      "aa"
      "ta"
      "borg"
    ];
    primaryUsername = lib.mkForce "aa";
    username = lib.mkForce "aa";

    # System type flags
    isWork = lib.mkForce false;
    isProduction = lib.mkForce true;
    isRemote = lib.mkForce true;
    isServer = lib.mkForce true;
    isAutoStyled = lib.mkForce false;
    useWindowManager = lib.mkForce false;

    # Functionality
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
  services.dyndns.enable = true;

  environment.systemPackages = [ pkgs.borgbackup ];

  services.remoteLuksUnlock = {
    enable = true;
    notify.to = config.hostSpec.email.mothAdmins;
  };

  # Override the physical key to reboot on short press
  services.logind.settings.Login.HandlePowerKey = lib.mkForce "reboot";

  # Setup NUT server and corresponding client for USB-attached UPS device
  services.ups = {
    server.enable = true;
    username = "nut";
    name = "cyberpower";
    powerDownTimeOut = (2 * 60); # 2m. UPS reports ~10min
  };
  power.ups.ups.cyberpower = {
    driver = "usbhid-ups";
    description = "CyberPower CP1500PFCLCDa";
    port = "auto";
    directives = [
      "vendorid = 0764"
      "productid = 0601"
    ];
  };

  systemd = {
    tmpfiles.rules =
      let
        name = user: config.users.users.${user}.name;
        group = user: config.users.users.${user}.group;
      in
      [
        "d /mnt/storage/backup/ 0750 ${name "borg"} ${group "borg"} -"
        "d /mnt/storage/mirror/ 0750 ${name "borg"} ${group "borg"} -"
        "d /mnt/storage/backup/ta 0700 ${name "ta"} ${group "ta"} -"
      ];
  };

  services.mirror-backups = {
    enable = true;
    time = "*-*-* 5:00:00"; # Keep sync with myth times
    server = "myth.${config.hostSpec.domain}";
  };
  # Allow myth to mirror into moth
  users.users.borg.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICMso7GIZT7pDRxeE8xd+hkwUySI8v8LwvDn1gPJyGFK root@myth"
  ];

  # FIXME:
  # services.backup = {
  #   enable = true;
  #   borgBackupStartTime = "09:00:00";
  # };

  system.stateVersion = "23.05";
}
