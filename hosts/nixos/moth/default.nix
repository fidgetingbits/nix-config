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
          # Services
          "services/openssh.nix"
          "services/ddclient.nix"

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
    configurationLimit = lib.mkDefault 8;
    consoleMode = "1";
  };
  boot.loader.efi.canTouchEfiVariables = true;

  services.remoteLuksUnlock = {
    enable = true;
    notify = {
      enable = true; # Off until we can set it up correctly on moth
      to = config.hostSpec.email.mothAdmins;
    };
  };

  # Override the physical key to reboot on short press
  services.logind.powerKey = lib.mkForce "reboot";

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
        "d /mnt/storage/backup/ta 0700 ${name "ta"} ${group "ta"} -"
      ];
  };

  # FIXME:
  # services.backup = {
  #   enable = true;
  #   borgBackupStartTime = "09:00:00";
  # };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = "23.05";
}
