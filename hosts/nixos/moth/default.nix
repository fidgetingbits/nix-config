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
    (lib.custom.scanPaths ./.) # Load all extra host-specific *.nix files

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
          "mail-delivery.nix"
          "logind.nix"
          "cli.nix"
        ])
    ))
  ];

  system.impermanence.enable = true;
  services.dyndns.enable = true;

  environment.systemPackages = [ pkgs.borgbackup ];

  services.remoteLuksUnlock = {
    enable = true;
    notify.to = config.hostSpec.email.mothAdmins;
    ssh.users = [
      "aa"
      "ta"
    ];
  };

  # Override the physical key to reboot on short press
  services.logind.settings.Login.HandlePowerKey = lib.mkForce "reboot";

  # Setup NUT server and corresponding client for USB-attached UPS device
  services.ups = {
    server.enable = false;
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
        "d /mnt/storage/backup/ 2750 ${name "borg"} ${group "borg"} -"
        "d /mnt/storage/mirror/ 2750 ${name "borg"} ${group "borg"} -"
        # FIXME: This should loop over users that we've setup with hm?
        "d /mnt/storage/backup/ta 0700 ${name "ta"} ${group "ta"} -"
      ];
  };

  services.mirror-backups = {
    enable = true;
    notify.to = config.hostSpec.email.mothAdmins;
    time = "*-*-* 5:00:00"; # Keep sync with myth times
    server = "myth.${config.hostSpec.domain}";
  };

  # Allow myth to mirror into moth
  users.users.borg.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICMso7GIZT7pDRxeE8xd+hkwUySI8v8LwvDn1gPJyGFK root@myth"
  ];

  services.backup = {
    enable = true;
    borgBackupStartTime = "09:00:00";

    borgServer = "myth.${config.hostSpec.domain}";
    borgRemotePath = "/run/current-system/sw/bin/borg";
    borgBackupPath = "/mnt/storage/backup/aa";
    borgNotifyTo = config.hostSpec.email.mothAdmins;
  };
}
