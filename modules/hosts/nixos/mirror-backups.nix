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
  mirror-backups = pkgs.writeShellApplication rec {
    name = "mirror-backups";
    runtimeInputs = lib.attrValues {
      inherit (pkgs)
        msmtp
        coreutils
        rsync
        openssh
        util-linux
        bashNonInteractive
        ;
    };
    text =
      let
        recipients = lib.concatStringsSep ", " cfg.notify.to;
        leafFolders = lib.concatStringsSep " " cfg.folders.source.leafs;
        collectionFolders = lib.concatStringsSep " " cfg.folders.source.collections;
      in
      # bash
      ''
        function gen_sync_cmd {
          subfolder=$1
          log=$2
          destination=${cfg.folders.destination}/"$subfolder"
            # --chmod ensures the files are group-accessible on host B, even if
            # they aren't normally on host A. This is needed because we use a
            # different user to copy the files from host A to B.
          cat <<EOF
            ssh -l ${cfg.user} -i ${sshKeyPath} -p ${port} -oIdentitiesOnly=yes ${cfg.server} \
              "mkdir -p "$destination" 2>/dev/null|| true" && \
            rsync -aHS \
              --stats \
              --delete \
              --chmod=Dg+srwx,Fg+rw,o-rwx \
              -e "ssh -l ${cfg.user} -i ${sshKeyPath} -p ${port} -oIdentitiesOnly=yes" \
              ${cfg.folders.source.base}/"$subfolder" \
              ${cfg.server}:"$destination" >> "$log" 2>&1
        EOF
        }

        function run_sync_cmd {
          sync_cmd=$1
          log=$2
          systemd-inhibit --why="Mirror backups to ${cfg.server}" \
            --who="Backup Mirror Task" \
            --mode=block bash \
            -c "$sync_cmd"

          # NOTE: This will break if rsync is used with -v for testing
          first=$(grep . "$log" | head -1)
          if echo "$first" | grep -q "Number of files"; then
            echo "succeeded!"
          elif echo "$first" | grep -q "@@@@"; then
            echo "failed due to being in luks unlock state"
          else
            echo "result unknown"
          fi
        }

        function mail_results {
          result=$1
          log=$2
          exec msmtp -t <<EOF
        To: ${recipients}
        From: ${cfg.notify.from}
        Subject: [${config.networking.hostName}: mirror] Mirroring to ${cfg.server} $result

        $(cat "$log" || echo "ERROR: no logs")
        EOF
        }

        exec {LOCKFD}> /var/lock/${name}.lock
        if ! flock -n ''${LOCKFD}; then
          echo "Another backup running; exiting"
          exit 0
        fi

        # Temp logdir for accumulating per-sync log files
        logdir=$(mktemp -d)

        # Final log sent via email and preserved for follow up analysis
        mirror_log=/root/${name}-log.txt
        rm $mirror_log 2>/dev/null|| true

        declare -a folders
        folders=(${leafFolders})
        # Loop over each collections folder and sync each sub folder
        # shellcheck disable=SC2043
        for collection in "${collectionFolders}"; do
          while IFS= read -r -d "" folder
          do
            folders+=("$collection/$folder")
          done < <(find "${cfg.folders.source.base}/$collection" -mindepth 1 -maxdepth 1 -type d -printf "%P\0")
        done

        # Loop over each folder and copy it
        for folder in "''${folders[@]}"; do
          log=$(mktemp -p "$logdir")

          echo "Syncing ${cfg.folders.source.base}/$folder to ${cfg.server}:${cfg.folders.destination}/$folder"
          sync_cmd=$(gen_sync_cmd "$folder" "$log")
          result=$(run_sync_cmd "$sync_cmd" "$log")

          echo "${cfg.folders.source.base}/$folder to ${cfg.server}:${cfg.folders.destination}/$folder" >> "$mirror_log"
          echo "-----" >> "$mirror_log"
          cat "$log\n" >> "$mirror_log"
          echo "-----" >> "$mirror_log"

          if [[ ! "$result" = "succeeded"* ]]; then
            # Exit on first failure encountered
            mail_results "$result" "$mirror_log"
            exit 1
          fi
        done

        mail_results "succeeded!" "$mirror_log"
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
    user = lib.mkOption {
      type = lib.types.str;
      default = "borg";
      description = "The user to authenticate to the server with";
    };
    folders = {
      destination = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/storage/mirror/";
        description = "The path on the destination server to mirror to";
      };
      source = {

        base = lib.mkOption {
          type = lib.types.str;
          default = "/mnt/storage/backup/";
          description = "The base path on the origin server to mirror files from";
        };
        leafs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            List of folders to mirror entirely to the destination server.

            For example: /a/b/c will use rsync --delete /a/b/c to copy it to the
            destination and any additional contents in /a/b/c that were already on
            destination and are missing from source server will be deleted.

            This is suitable when /a/b/c is a folder ONLY used by the system
            mirroring this folder.

            If multiple servers share a parent folder that needs to have some
            contents backed up, use collectionFolders instead.
          '';
        };
        collections = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            List of folders whose containing folders should be copied to destination.

            For example: given folders /a/b/{c,d,e}, passing /a/b to collectionFolders will
            individually rsync --delete /a/b/c, /a/b/d, and /a/b/e folders. If the
            destination already had the /a/b folder and some other sub folders
            /a/b/foo, /a/b/bar, those folders will NOT be deleted.

            This is to be used when multiple servers use the same directory heirarchy, and you want to
            copy underlying folders without deleting missing folders from the parent.
            to delete any missing contents from this same folder on the destination. DO NOT
            use this to mirror a folder that other systems also mirror to the destination.

            This allows multiple backup servers to mirror their subfolders to a central folder without
            having to specify a unique parent folder, which simplifies backup access for users
            recovering from the mirror.
          '';

        };
      };
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
