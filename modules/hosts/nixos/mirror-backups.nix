{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.mirror-backups;
  sshKeyPath = "/root/.ssh/id_borg";
  port = toString config.hostSpec.networking.ports.tcp.ssh;
  # FIXME: This needs to be part of a loop that is per-mirror
  mirror-backups = pkgs.writeShellApplication {
    name = "mirror-backups";
    runtimeInputs = lib.attrValues {
      inherit (pkgs)
        msmtp
        coreutils
        rsync
        openssh
        util-linux
        ;
    };
    text =
      let
        recipients = lib.concatStringsSep ", " cfg.notify.to;
      in
      # FIXME: lockfd path should be changed to the per-script name when we have multiple mirror scripts
      # bash
      ''
        exec {LOCKFD}> /var/lock/mirror-backups.lock
        if ! flock -n ''${LOCKFD}; then
          echo "Another backup running; exiting"
          exit 0
        fi

        LOG=/root/mirror-log.txt
        # --chmod ensures the files are group-accessible on host B, even if
        # they aren't normally on host A. This is needed because we use a
        # different user to copy the files from host A to B.
        #
        # I don't use --checksum since some of our backup servers use nvme. This
        # technically risks missing disk corruption. But periodic disk validation
        # on the hosts should notify of this.
        # FIXME: run this in a loop until it definitely finishes, similar to long-rsync?
        SYNC_CMD=$(cat <<EOF
        rsync -e "ssh -l ${cfg.user} -i ${sshKeyPath} -p ${port} -oIdentitiesOnly=yes" \
          -aHS --stats \
          --delete \
          --chmod=Dg+srwx,Fg+rw,o-rwx \
          ${lib.concatStringsSep " " cfg.folders} \
          ${cfg.server}:${cfg.destinationPath} 2>&1 | tee $LOG
        EOF
        )

        systemd-inhibit --why="Mirror backups to ${cfg.server}" --who="Backup Mirror Task" --mode=block ${lib.getExe pkgs.bash} -c "$SYNC_CMD"

        if head -1 $LOG | grep -q "Number of files"; then
          RESULT="succeeded"
        elif head -1 $LOG | grep -q "@@@@"; then
          RESULT="failed due to being in luks unlock state"
        else
          RESULT="result unknown"
        fi


        exec msmtp -t  <<EOF
        To: ${recipients}
        From: ${cfg.notify.from}
        Subject: [${config.networking.hostName}: mirror] Mirroring to ${cfg.server} $RESULT

        $(cat /root/mirror-log.txt)
        EOF
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
    package = lib.mkOption {
      type = lib.types.package;
      description = "Script package to use for the mirroring";
      default = mirror-backups;
    };
    destinationPath = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/storage/mirror/";
      description = "The path on the destination server to mirror to";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "borg";
      description = "The user to authenticate to the server with";
    };
    folders = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "/mnt/storage/backup/" ];
      description = "List of folders to mirror to the destination server";
    };
    time = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 4:00:00";
      description = "systemd OnCalender time to trigger the mirroring.";
    };
    notify = lib.mkOption {
      type = lib.types.submodule {
        options = {
          to = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ config.hostSpec.email.admin ];
            example = [ "admin@example.com" ];
            description = "List of emails to send notifications to";
          };
          from = lib.mkOption {
            type = lib.types.str;
            default = config.hostSpec.email.notifier;
            example = "notifications@example.com";
            description = "Email address to send notifications from";
          };
        };

      };
      default = { };
    };
  };
  config = lib.mkIf cfg.enable ({
    systemd = {
      services."mirror-backups" = {
        description = "Mirror local backups to the remote system";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.bash}/bin/bash ${lib.getExe cfg.package}";
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

    # same borg key used for local backups can be used to mirror other backups
    # to the same backup server
    sops.secrets."keys/ssh/borg" = {
      owner = "root";
      mode = "0400";
      path = sshKeyPath;
    };
  });
}
