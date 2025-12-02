{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.mirror-backups;
  sshKeyPath = "/etc/ssh/mirror_ed25519";
  port = toString config.hostSpec.networking.ports.tcp.ssh;
  mirror-backups = pkgs.writeShellApplication {
    name = "mirror-backups";
    runtimeInputs = builtins.attrValues {
      inherit (pkgs)
        msmtp
        coreutils
        rsync
        openssh
        util-linux
        ;
    };
    text = ''
      exec {LOCKFD}> /var/lock/mirror-backups.lock
      if ! flock -n ''${LOCKFD}; then
        echo "Another backup running; exiting"
        exit 0
      fi
      rsync -e 'ssh -l ${cfg.user} -i ${sshKeyPath} -p ${port}' \
        -cau --no-p --stats \
        ${lib.concatStringsSep " " cfg.folders} \
        ${cfg.server}:${cfg.destinationPath} | tee /root/mirror-log.txt

      TMPDIR=$(mktemp -d)
      cat >"$TMPDIR"/mirror.txt <<-EOF
      From:box@${config.hostSpec.domain}
      Subject: [${config.networking.hostName}: mirror] Mirroring to ${cfg.server} complete
      $(cat /root/mirror-log.txt)
      EOF
      msmtp -t admin@${config.hostSpec.domain} <"$TMPDIR"/mirror.txt
      rm -rf "$TMPDIR"
    '';
  };
in
{
  options.services.mirror-backups = {
    enable = lib.mkEnableOption "Run a timer to mirror one systems backups to another";
    server = lib.mkOption {
      type = lib.types.str;
      description = "The server to mirror to";
    };
    destinationPath = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/storage/mirror/";
      description = "The path on the destination server to mirror to";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "borg";
      description = "The user to authenticate with to the server";
    };
    folders = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "/mnt/storage/backup/" ];
      description = "List of folders to mirror to the destination host";
    };
    time = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 4:00:00";
      description = "systemd OnCalender time to trigger the mirroring.";
    };
  };
  # FIXME: Check if the disks are getting too full?
  config = lib.mkIf cfg.enable ({
    systemd = {
      services."mirror-backups" = {
        description = "Mirror local backups to the remote system";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.bash}/bin/bash ${lib.getExe' mirror-backups "mirror-backups"}";
          RemainAfterExit = false;
        };
      };
      timers."mirror-backups" = {
        description = "Mirror local backups to the remote system";
        wantedBy = [ "timers.target" ];
        after = [ "network-online.target" ];
        requires = [ "network-online.target" ];
        timerConfig = {
          OnCalendar = cfg.time;
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };
    };

    sops.secrets."keys/ssh/mirror_ed25519" = {
      owner = "root";
      mode = "0400";
      path = sshKeyPath;
    };
  });
}
