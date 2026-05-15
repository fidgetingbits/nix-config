{
  config,
  pkgs,
  lib,
  ...
}:
{

  environment.systemPackages = [ pkgs.borgbackup ];

  systemd = {
    tmpfiles.rules =
      let
        name = user: config.users.users.${user}.name;
        group = user: config.users.users.${user}.group;
      in
      [
        # d+ will fix up perms if they go bad
        "d+ /mnt/storage/backup/ 2770 ${name "borg"} ${group "borg"} -"
        "d+ /mnt/storage/mirror/ 2770 ${name "borg"} ${group "borg"} -"
        # Because we mirror from oath, which doesn't already use aa/ prefix for copying
        "d /mnt/storage/mirror/aa 2770 ${name "borg"} ${group "borg"} -"
      ]
      # In some cases borg user is used to backup to these folders, so needs users access
      ++ (lib.map (u: "d /mnt/storage/backup/${u} 0770 ${name "${u}"} ${group "${u}"} -") [
        "aa"
        "ta"
      ]);
  };
  systemd.services.systemd-tmpfiles-setup = {
    after = [ "mnt-storage.mount" ];
    requires = [ "mnt-storage.mount" ];
  };

  services.mirror-backups = {
    enable = true;
    notify.to = config.hostSpec.email.${config.hostSpec.hostName}.backups;

    # Moth local time. NOTE: Keep roughly in sync with myth times
    time = "*-*-* 5:30:00"; # Keep sync with myth times
    server = "myth.${config.hostSpec.domain}";
    folders = {
      destination = "/mnt/storage/mirror";
      source = {
        base = "/mnt/storage/backup";
        collections = [
          "aa"
          "ta"
        ];
      };
    };
  };

  # Allow other servers to mirror their backups into moth
  users.users.borg.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICMso7GIZT7pDRxeE8xd+hkwUySI8v8LwvDn1gPJyGFK myth"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOLLKlQQu/pl8e/Vs3c60crZqjwhB/GV3C58EmTD/L1y ooze"
  ];

  services.backup = {
    enable = true;
    # Moth local time. NOTE: Keep roughly in sync with myth times
    borgBackupStartTime = "*-*-* 05:00:00";
    borgServer = "myth.${config.hostSpec.domain}";
    borgRemotePath = "/run/current-system/sw/bin/borg";
    borgBackupPath = "/mnt/storage/backup/aa";
    borgNotifyTo = config.hostSpec.email.${config.hostSpec.hostName}.backups;
  };

}
