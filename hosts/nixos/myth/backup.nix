# FIXME:This file could be de-duplicated between myth/moth probably
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
        "d+ /mnt/storage/backup/ 2770 ${name "borg"} ${group "borg"} -"
        "d+ /mnt/storage/mirror/ 2770 ${name "borg"} ${group "borg"} -"
        "d+ /mnt/storage/share/ 2770 ${name "aa"} ${group "aa"} -"
      ]
      ++ (lib.map (u: "d /mnt/storage/backup/${u} 0770 ${name "${u}"} ${group "${u}"} -") [
        "pa"
        "aa"
      ]);
  };

  services.mirror-backups = {
    enable = true;
    # Myth local time. NOTE: Keep roughly in sync with moth times
    time = "*-*-* 4:00:00";
    server = "moth.${config.hostSpec.domain}";
    notify.to = config.hostSpec.email.${config.hostSpec.hostName}.backups;

    folders = {
      destination = "/mnt/storage/mirror";
      source = {
        base = "/mnt/storage/backup";
        leafs = [ "pa" ];
        collections = [ "aa" ];
      };
    };
  };

  # Allow moth to mirror into myth
  users.users.borg.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKZp+oB8eZjz/S5Q8T8uFfq2yCt5NQWI3/Mm6q+ToAsA root@moth"
  ];

  services.backup = {
    enable = true;

    # Myth local time. NOTE: Keep roughly in sync with moth times
    borgBackupStartTime = "*-*-* 04:30:00";

    borgServer = "moth.${config.hostSpec.domain}";
    borgRemotePath = "/run/current-system/sw/bin/borg";
    borgBackupPath = "/mnt/storage/backup/aa";
    borgNotifyTo = config.hostSpec.email.${config.hostSpec.hostName}.backups;
  };

}
