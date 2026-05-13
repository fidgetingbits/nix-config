# FIXME(backup): Backups can silently fail if the exclusive.lock is not removed from a failed backup
#                probably need a script to verify from a list if the lock is held, because backup itself
#                will not return an error code if it fails to acquire the lock. Probably shouldn't auto
#                break the lock, but should notify the user that the lock is held and they should break it
# ❯ sudo borg-backup-list
# Failed to create/acquire the lock /.cache/borg/34c1f55fdbfea2f94c932b089804f1cd0b3cca2f5294ef46383fe002a324539e/lock.exclusive (timeout).
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.services.backup;
  hasPerNetworkServices = lib.hasAttr "per-network-services" config.services;
  hasImpermanence = config.introdus.impermanence.enable;

  hostName = config.networking.hostName;
  homeBase = if pkgs.stdenv.isLinux then "/home" else "/Users";
  homeDirectory = config.hostSpec.home;
  rootHome = if pkgs.stdenv.isLinux then config.users.users.root.home else "/var/root";
  excludes = lib.flatten [
    "**/.direnv"
    "**/.cache"
    "**/.npm"
    "**/.npm-global"
    "**/.node-gyp"
    "**/.yarn"
    "**/.pnpm-store"
    "**/.m2"
    "**/.gradle"
    "**/.opam"
    "**/.clangd"
    # Python
    "**/*.pyc"
    # Rust
    "**/.cargo"
    "**/.rustup"
    "**/target" # FIXME(borg): This might be too aggressive
    # Nix
    "**/result"
    # Lua
    "**/.luarocks"
    # /home/*/<foo> entries
    (lib.map (path: "${homeBase}/${path}") [
      # Common home cache files/directories
      "*/.mozilla/firefox/*/storage"
      "*/Android"
      "*/mount"
      "*/mnt"
      "*/.cursorless"
      # Go
      "*/go/pkg"
    ])
    # FIXME: These can just maybe go into a .lst file with the other macos ones

    # Root folders, these only matter on non-impermanence systems
    "/dev"
    "/proc"
    "/sys"
    "/var/run"
    "/run"
    "/lost+found"
    "/mnt"

    # FIXME(borg): To double check
    "/var/lib/lxcfs"

    # System cache files/directories
    "/var/lib/containerd"
    "/var/lib/docker/"
    "/var/lib/systemd"
    "/var/cache"
    "/var/tmp"
  ];
  borgExcludesFile = pkgs.writeText "borg-excludes.lst" (
    lib.concatMapStrings (s: s + "\n") (excludes ++ cfg.borgExcludes)
  );
  darwinExcludesFile = pkgs.writeText "borg-exclude-macos-core.list" (
    lib.readFile ./borg-exclude-macos-core.list
  );

in
{
  options.services.backup = {
    enable = lib.mkEnableOption "Enable borg-based backup tooling";
    enableService = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the borg backup service";
    };
    borgUser = lib.mkOption {
      type = lib.types.str;
      default = "borg";
      description = "The user to run the borg backup as";
    };
    borgServer = lib.mkOption {
      type = lib.types.str;
      default = "oath";
      description = "The borg server to backup to";
    };
    borgPort = lib.mkOption {
      type = lib.types.int;
      default = config.hostSpec.networking.ports.tcp.ssh;
      description = "The ssh port to use for the borg server";
    };
    borgBackupPath = lib.mkOption {
      type = lib.types.str;
      default = "/volume1/backups";
      description = "The path on the borg server to store backups";
    };
    borgSshKey = lib.mkOption {
      type = lib.types.str;
      default = "${rootHome}/.ssh/id_borg";
      description = "The ssh key to use for borg";
    };
    borgNotifyFrom = lib.mkOption {
      type = lib.types.str;
      default = config.hostSpec.email.notifier;
      description = "The email address that msmtp notifications will be sent from";
    };
    borgNotifyTo = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ config.hostSpec.email.admin ];
      description = "The email address that msmtp notifications will be sent to";
    };
    borgRemotePath = lib.mkOption {
      type = lib.types.str;
      default = "/usr/local/bin/borg";
      description = "The borg binary path on the borg server";
    };
    borgMountDir = lib.mkOption {
      type = lib.types.str;
      default = "${homeDirectory}/mount/backup";
      description = "The directory to mount backups to";
    };
    borgCacheDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.hostSpec.persistFolder}/.cache/borg";
      description = "The cache directory for borg";
    };
    borgBackupPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "${homeDirectory}" ];
      description = "The paths on host to backup";
    };
    borgBackupName = lib.mkOption {
      type = lib.types.str;
      default = "${config.networking.hostName}-$(date +%Y-%m-%d_%H-%M)";
      description = "The name of the backup";
    };
    borgBtrfsVolume = lib.mkOption {
      type = lib.types.str;
      default = "/dev/mapper/encrypted-nixos";
      description = "The btrfs volume containing the subvolume backup";
    };
    borgBtrfsSubvolume = lib.mkOption {
      type = lib.types.str;
      default = "@persist";
      description = "The btrfs subvolume to mount and backup";
    };
    borgBackupExpiryDaily = lib.mkOption {
      type = lib.types.int;
      default = 7;
      description = "The number of daily backups to keep";
    };
    borgBackupExpiryWeekly = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "The number of weekly backups to keep";
    };
    borgBackupExpiryMonthly = lib.mkOption {
      type = lib.types.int;
      default = 6;
      description = "The number of monthly backups to keep";
    };
    borgBackupExpiryYearly = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = "The number of yearly backups to keep";
    };
    borgBackupStartTime = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 00:00:00";
      description = "The time to start the backup";
    };
    borgBackupLogPath = lib.mkOption {
      type = lib.types.str;
      default = "${rootHome}/backup.log";
      description = "The log location for the backup";
    };
    borgExcludes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "A list of extra paths to exclude from the backup";
    };
  };

  config = lib.mkIf cfg.enable (
    let
      shellScriptHelpers = lib.readFile ./backup-helpers.sh;
      # See borg-backup-help tool to dump a summary of these
      shellScriptOptionHandling =
        # bash
        ''
          BORG_USER="''${BORG_USER:-${cfg.borgUser}}"
          BORG_SERVER="''${BORG_SERVER:-${cfg.borgServer}}"
          BORG_PORT="''${BORG_PORT:-${toString cfg.borgPort}}"
          BORG_HOST="''${BORG_HOST:-${config.networking.hostName}}"
          BORG_REMOTE_REPO="''${BORG_REMOTE_REPO:-${cfg.borgBackupPath}/$BORG_HOST}"
          #shellcheck disable=SC2304
          BORG_REMOTE="''${BORG_SERVER}:''${BORG_REMOTE_REPO}"
          export BORG_REMOTE # shutup shellcheck
          BORG_SSH_KEY="''${BORG_SSH_KEY:-${cfg.borgSshKey}}"
          BORG_REMOTE_PATH="''${BORG_REMOTE_PATH:-${cfg.borgRemotePath}}"
          BORG_BACKUP_NAME="''${BORG_BACKUP_NAME:-${cfg.borgBackupName}}"
          BORG_BACKUP_PATHS="''${BORG_BACKUP_PATHS:-${lib.concatStringsSep " " cfg.borgBackupPaths}}"
          if [ -v BORG_TRACE ]; then
            set -x
          fi

          # Export variables not used directly in script, or only used in some scripts
          export BORG_BTRFS_VOLUME="''${BORG_BTRFS_VOLUME:-${cfg.borgBtrfsVolume}}"
          export BORG_BTRFS_SUBVOLUME="''${BORG_BTRFS_SUBVOLUME:-${cfg.borgBtrfsSubvolume}}"
          export BORG_PASSPHRASE="''${BORG_PASSPHRASE:-$(cat /etc/borg/passphrase)}"
          if [ -z "$BORG_PASSPHRASE" ]; then
            echo "No BORG_PASSPHRASE set, exiting"
            exit 1
          fi

          export BORG_RSH="ssh -i $BORG_SSH_KEY -l$BORG_USER -oport=$BORG_PORT -oUpdateHostKeys=no"
          export BORG_EXPIRY="--keep-daily=${toString cfg.borgBackupExpiryDaily} \
            --keep-weekly=${toString cfg.borgBackupExpiryWeekly} \
            --keep-monthly=${toString cfg.borgBackupExpiryMonthly} \
            --keep-yearly=${toString cfg.borgBackupExpiryYearly}"
          export BORG_CACHE_DIR="''${BORG_CACHE_DIR:-${cfg.borgCacheDir}}"
          if [ ! -d "$BORG_CACHE_DIR" ]; then
            mkdir -p "$BORG_CACHE_DIR"
          fi

          # Non-variable options
          export BORG_RELOCATED_REPO_ACCESS_IS_OK=yes
          export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes
        '';

      shellScriptEmail =
        let
          recipients = lib.concatStringsSep ", " cfg.borgNotifyTo;
        in
        # bash
        ''
          function email_results() {
            SUBJECT="''${1:-Backup}"
            exec msmtp -t <<EOF
          To: ${recipients}
          From:${cfg.borgNotifyFrom}
          Subject: [$BORG_HOST: backup] $(date +%Y-%m-%d_%H-%M) $SUBJECT

          $(cat "$LOGFILE")
          EOF
          }
        '';

      shellScriptCheckLock =
        # bash
        ''
          ${lib.getBin borg-backup-list}/bin/borg-backup-list > /dev/null 2>$LOGFILE
          if grep -q "Failed to create/acquire the lock" $LOGFILE; then
            # For now we don't auto-break the lock, but notify the user to do so
            #borg-backup-break-lock
            echo "Run borg-backup-break-lock to break the lock" >> $LOGFILE
            email_results "Backup failed due to lock acquisition failure"
          fi
          echo > $LOGFILE
        '';

      borg-backup-test-email = pkgs.writeShellApplication {
        name = "borg-backup-test-email";
        runtimeInputs = [ pkgs.msmtp ];
        text =
          # bash
          ''
            TOOL_DESCRIPTION="Test borg script email sending function"
            ${shellScriptHelpers}
            ${shellScriptEmail}
            LOGFILE=$(mktemp)
            echo "Test backup from $(hostname)" >"$LOGFILE"
            email_results
          '';
      };

      borg-backup-btrfs-subvolume = pkgs.writeShellApplication {
        name = "borg-backup-btrfs-subvolume";
        runtimeInputs = [
          pkgs.borgbackup
          pkgs.nettools
          pkgs.mount
          pkgs.umount
          pkgs.msmtp
          borg-backup-init
          borg-backup-list
        ];
        text =
          # bash
          ''
            TOOL_DESCRIPTION="Use borg to backup a btrfs subvolume"
            ${shellScriptOptionHandling}
            ${shellScriptHelpers}
            ${shellScriptEmail}
            parse_args "0" "$@"
            LOGFILE="${cfg.borgBackupLogPath}"

            # Configure a new backup if one doesn't already exist
            # Redirect errors to avoid confusing with constant "A repo already exists at" spam
            borg-backup-init 2>/dev/null 1>&2 || true

            ${shellScriptCheckLock}

            function borg_backup() {
              MOUNTDIR=$(mktemp -d)
              mount -t btrfs -o subvol=/ "$BORG_BTRFS_VOLUME" "$MOUNTDIR"
              BACKUP_PATH="$MOUNTDIR/$BORG_BTRFS_SUBVOLUME"
              # Borg doesn't let you specify the source parent folder that you
              # want to recover, we enter the temp folder to prevent it from
              # showing up while doing recoveries
              cd "$BACKUP_PATH"
              #shellcheck disable=SC2086
              if borg create --remote-path $BORG_REMOTE_PATH -v --stats --exclude-caches "$BORG_REMOTE::$BORG_BACKUP_NAME" $PWD \
                --exclude-if-present .nobackup \
                ${if pkgs.stdenv.isDarwin then "--exclude-from ${darwinExcludesFile}" else " "} \
                --exclude-from ${borgExcludesFile}; then
                # NOTE: --glob-archives works like a tag, so we can rename pinned backups with a none matching prefix like pinned-...
                borg prune --remote-path $BORG_REMOTE_PATH -v --list "$BORG_REMOTE" --glob-archives "$BORG_HOST-*" $BORG_EXPIRY
              fi
              cd -
              umount "$MOUNTDIR"
            }
            borg_backup >$LOGFILE 2>&1
            email_results
          '';
      };

      borg-backup-paths = pkgs.writeShellApplication {
        name = "borg-backup-paths";
        runtimeInputs = [
          pkgs.borgbackup
          pkgs.mount
          pkgs.msmtp
          borg-backup-init
          borg-backup-list
        ];
        text =
          # bash
          ''
            TOOL_DESCRIPTION="Use borg to backup a list of paths"
            ${shellScriptOptionHandling}
            ${shellScriptHelpers}
            ${shellScriptEmail}
            parse_args "0" "$@"
            LOGFILE="${cfg.borgBackupLogPath}"

            # Configure a new backup if one doesn't already exist
            borg-backup-init 2>/dev/null 1>&2 || true

            ${shellScriptCheckLock}

            function borg_backup() {
                # samba mounts that we want to exclude from the backup
                MOUNT_EXCLUDES=()
                for MOUNT in $(mount | grep -i cifs | cut -d" " -f3); do
                    MOUNT_EXCLUDES+=("--exclude $MOUNT")
                done
                # FIXME(borg): Add a check to see if we need to run borg init
                #shellcheck disable=SC2096,SC2068,SC2086
                if borg create --remote-path $BORG_REMOTE_PATH -v --stats --exclude-caches "$BORG_REMOTE::$BORG_BACKUP_NAME" \
                  $BORG_BACKUP_PATHS \
                  --exclude-from ${borgExcludesFile} \
                  ''${MOUNT_EXCLUDES[@]}; then
                  borg prune --remote-path $BORG_REMOTE_PATH -v --list "$BORG_REMOTE" --glob-archives "$BORG_HOST-*" $BORG_EXPIRY
                fi
              }
            borg_backup >$LOGFILE 2>&1
            email_results
          '';
      };

      borg-backup-mount = pkgs.writeShellApplication {
        name = "borg-backup-mount";
        runtimeInputs = [ pkgs.borgbackup ];
        text =
          # bash
          ''
            TOOL_DESCRIPTION="Mount a specified backup to a local directory"
            USAGE="<backup_name>"
            ${shellScriptOptionHandling}
            ${shellScriptHelpers}

            parse_args "1" "$@"
            backup_name="''${POSITIONAL_ARGS[0]}"

            BORG_MOUNT_PATH="''${BORG_MOUNT_PATH:-${cfg.borgMountDir}/$BORG_HOST}/"
            if [ ! -d "$BORG_MOUNT_PATH" ]; then
              mkdir -p "$BORG_MOUNT_PATH"
              echo "Created missing mount directory $BORG_MOUNT_PATH"
            fi

            #shellcheck disable=SC2086
            borg mount --remote-path $BORG_REMOTE_PATH -v "$BORG_REMOTE"::"$backup_name" "$BORG_MOUNT_PATH"
            echo "Backup mounted at $BORG_MOUNT_PATH"
          '';
      };

      borg-backup-umount = pkgs.writeShellApplication {
        name = "borg-backup-umount";
        runtimeInputs = [ pkgs.borgbackup ];
        text =
          # bash
          ''
            TOOL_DESCRIPTION="Unmount BORG_BACKUP_NAME backup path (Default: ${cfg.borgMountDir}/${hostName})"
            ${shellScriptOptionHandling}
            ${shellScriptHelpers}

            parse_args "0" "$@"

            BORG_MOUNT_PATH="''${BORG_MOUNT_PATH:-${cfg.borgMountDir}/$BORG_HOST}/"
            if [ ! -d "$BORG_MOUNT_PATH" ]; then
              echo "Mount directory $BORG_MOUNT_PATH does not exist"
              exit 1
            fi

            #shellcheck disable=SC2086
            borg umount "$BORG_MOUNT_PATH"
            echo "Backup unmounted from $BORG_MOUNT_PATH"
          '';
      };

      borg-backup-mount-list = pkgs.writeShellApplication {
        name = "borg-backup-mount-list";
        runtimeInputs = [ pkgs.borgbackup ];
        text =
          # bash
          ''
            mount | grep borgfs
          '';
      };

      borg-backup-list = pkgs.writeShellApplication {
        name = "borg-backup-list";
        runtimeInputs = [ pkgs.borgbackup ];
        text = # bash
          ''
            TOOL_DESCRIPTION="List borg backups"
            ${shellScriptOptionHandling}
            ${shellScriptHelpers}

            parse_args "0" "$@"

            #shellcheck disable=SC2086
            borg list --remote-path $BORG_REMOTE_PATH $BORG_REMOTE
          '';
      };

      borg-backup-break-lock = pkgs.writeShellApplication {
        name = "borg-backup-break-lock";
        runtimeInputs = [ pkgs.borgbackup ];
        text =
          # bash
          ''
            TOOL_DESCRIPTION="Break a borg lock from a failed run"
            ${shellScriptOptionHandling}
            ${shellScriptHelpers}

            parse_args "0" "$@"

            #shellcheck disable=SC2086
            borg break-lock --remote-path $BORG_REMOTE_PATH $BORG_REMOTE
          '';
      };

      borg-backup-init = pkgs.writeShellApplication {
        name = "borg-backup-init";
        runtimeInputs = [ pkgs.borgbackup ];
        text =
          # bash
          ''
            TOOL_DESCRIPTION="Initialize a borg backup repository"
            ${shellScriptOptionHandling}
            ${shellScriptHelpers}

            parse_args "0" "$@"

            #shellcheck disable=SC2086
            borg init --remote-path $BORG_REMOTE_PATH --encryption=repokey "$BORG_REMOTE"
          '';
      };

      borg-backup-rename = pkgs.writeShellApplication {
        name = "borg-backup-rename";
        runtimeInputs = [ pkgs.borgbackup ];
        text =
          # bash
          ''
            TOOL_DESCRIPTION="Rename a borg backup"
            USAGE="<backup_name> <new_name>"
            ${shellScriptOptionHandling}
            ${shellScriptHelpers}

            parse_args "2" "$@"
            backup_name="''${POSITIONAL_ARGS[0]}"
            new_name="''${POSITIONAL_ARGS[1]}"

            #shellcheck disable=SC2086
            borg rename --remote-path $BORG_REMOTE_PATH -v "$BORG_REMOTE"::"$backup_name" "$new_name"
            echo "Renamed backup $backup_name with new_name $new_name"
          '';
      };

      borg-backup-delete = pkgs.writeShellApplication {
        name = "borg-backup-delete";
        runtimeInputs = [ pkgs.borgbackup ];
        text =
          # bash
          ''
            TOOL_DESCRIPTION="Delete a borg backup"
            USAGE="<backup_name>"
            ${shellScriptOptionHandling}
            ${shellScriptHelpers}

            parse_args "1" "$@"
            backup_name="''${POSITIONAL_ARGS[0]}"

            #shellcheck disable=SC2086,SC2068
            borg delete --dry-run --remote-path $BORG_REMOTE_PATH -v --list \
              "$BORG_REMOTE"::"$backup_name" \
              ''${POSITIONAL_ARGS[@]:1:''${#POSITIONAL_ARGS[@]}-1}
            echo "Deleted backup $backup_name"
          '';
      };

      # See https://borgbackup.readthedocs.io/en/stable/usage/extract.html
      borg-backup-restore = pkgs.writeShellApplication {
        name = "borg-backup-restore";
        runtimeInputs = [ pkgs.borgbackup ];
        text =
          # bash
          ''
            TOOL_DESCRIPTION="Restore from a borg backup"
            USAGE="<backup_name> <restore_path>"
            ${shellScriptOptionHandling}
            ${shellScriptHelpers}

            parse_args "2" "$@"
            backup_name="''${POSITIONAL_ARGS[0]}"
            restore_path="''${POSITIONAL_ARGS[1]}"

            #shellcheck disable=SC2086,SC2068
            borg extract --remote-path $BORG_REMOTE_PATH -v \
              "$BORG_REMOTE"::"$backup_name" \
              --strip-components 1 -p "$restore_path" \
              --list \
              ''${POSITIONAL_ARGS[@]:2:''${#POSITIONAL_ARGS[@]}-1}

            echo "Restored backup $backup_name to $restore_path"
          '';
      };
      borg-backup-help = pkgs.writeShellApplication {
        name = "borg-backup-help";
        text = ''
          cat <<EOF
          ========================================================================
          BORG BACKUP TOOLS
          ========================================================================
          These are a custom set of tools for handling host-specific backups, but
          that are also catered to managing backups of other hosts in a way that
          doesn't require remembering/tweaking cli arguments.

          By default you will have a set of values declared by your Nix config, which
          handle your hosts backups on some primary backup server. These defaults
          will be used whenever running the scripts.

          However, you sometimes may need to admin or inspect other host's backups
          from a system that already has it's own defaults, in which case you can
          tweak environment variables to adjust behavior. These variables, as well
          as the backup tools, are described below.

          ========================================================================
          BORG BACKUP ENVIRONMENT SUMMARY
          ========================================================================
          These variables control how the borg-backup-* tools behave. You can
          override them in your shell to target different repos and run a
          group of commands specific to a "session". Most values shouldn't
          need to be modified, and not all variables are shown below. For
          source of truth, read the source.

          VARIABLE             DEFAULT VALUES ON THIS SYSTEM
          ------------------------------------------------------------------------
          BORG_SERVER          ${cfg.borgServer}
          BORG_HOST            ${config.networking.hostName}
          BORG_PORT            ${toString cfg.borgPort}
          BORG_USER            ${cfg.borgUser}

          BORG_REMOTE_REPO     ${cfg.borgBackupPath}/${config.networking.hostName}
          BORG_REMOTE_PATH     ${cfg.borgRemotePath}
          BORG_SSH_KEY         ${cfg.borgSshKey}
          BORG_CACHE_DIR       ${cfg.borgCacheDir}
          BORG_LOG_PATH        ${cfg.borgBackupLogPath}
          BORG_MOUNT_PATH      ${cfg.borgMountDir}
          BORG_BACKUP_NAME     ${config.networking.hostName}-\$(date +%Y-%m-%d_%H-%M)
          BORG_BACKUP_PATHS    ${lib.concatStringsSep " " cfg.borgBackupPaths}}

          BORG_BTRFS_VOLUME    ${cfg.borgBtrfsVolume}
          BORG_BTRFS_SUBVOLUME ${cfg.borgBtrfsSubvolume}
          BORG_PASSPHRASE      Read automatically from /etc/borg/passphrase
          ------------------------------------------------------------------------

          WHEN TO OVERRIDE:
          - Change BORG_HOST to list/restore backups from a different machine.
          - Set BORG_TRACE=1 to see raw command execution (set -x).
          - Override BORG_SERVER/BORG_PORT if you are analyzing backups that aren't
            on the default server your system uses
          - BORG_REMOTE_PATH will differ if the server is NixOS, Synology, etc

          ========================================================================
          BORG BACKUP TOOLSET SUMMARY
          ========================================================================

          Most commands can be run without arguments, as they will use the
          default environment variables shown above.

          CORE COMMANDS
          - borg-backup-btrfs-subvolume: Backs up the @persist subvolume.
          - borg-backup-paths:           Runs the standard backup of configured paths.
                                         Not typically used if using persistence.
          - borg-backup-init:            Initializes a new repo on the remote server.
                                         Auto-run by borg-backup-btrfs-subvolume and borg-backup-paths
          - borg-backup-list:            Lists all archives in the remote repository.
          - borg-backup-help:            Shows borg-backup tool help output

          RESTORATION & INSPECTION
          - borg-backup-mount:           Mounts an archive to ${cfg.borgMountDir}.
          - borg-backup-umount:          Unmounts the backup directory.
          - borg-backup-restore:         Extracts an archive to a specific path.
          - borg-backup-mount-list:      Shows active FUSE/borgfs mounts.

          MAINTENANCE
          - borg-backup-rename:          Renames an existing archive.
          - borg-backup-delete:          Deletes a specific archive (uses --dry-run by default).
          - borg-backup-break-lock:      Clears a stale lock on the remote repository.
          - borg-backup-test-email:      Sends a test email via msmtp.

          DO YOU WANT TO KNOW MORE?
          - For tool usage examples run the command "tldr borg-backup"
          ========================================================================
          EOF
        '';
      };
      # FIXME: Add more explicit examples from atuin history
      borgTldrPage = pkgs.writeText "borg-backup.page.md" ''
        # borg-backup

        > Custom backup toolset using borg. See `borg-backup-help` for argument overrides

        - List all existing archives in the repository:
          `borg-backup-list`

        - List all existing archives in the repository, for a different host:
          `read -s -p "Passphrase:" BORG_PASSPHRASE && BORG_HOST=oedo borg-backup-list`

        - Start a manual backup of the @persist btrfs subvolume:
          `borg-backup-btrfs-subvolume`

        - Start a manual backup of configured paths:
          `borg-backup-paths`

        - Mount a specific archive to examine files:
          `borg-backup-mount <archive_name>`

        - Restore a backup to a specific directory:
          `borg-backup-restore <archive_name> <target_path>`

        - Break a stale lock if a previous backup crashed:
          `borg-backup-break-lock`

        - View environment variables and defaults:
          `borg-backup-help`

        - Initialize the remote backup repository:
          `borg-backup-init`
      '';

      borgTldrPackage =
        pkgs.runCommand "borg-backup-tldr-page-install" { }
          # bash
          ''
            mkdir -p $out/share/tldr/
            cp ${borgTldrPage} $out/share/tldr/borg-backup.page.md
          '';

    in
    lib.mkMerge [
      {
        # FIXME: Most of these rely on sudo to access BORG_PASSPHRASE so could wrap it
        environment.systemPackages = [
          pkgs.borgbackup
          borg-backup-init
          borg-backup-list
          borg-backup-mount
          borg-backup-mount-list
          borg-backup-umount
          borg-backup-rename
          borg-backup-paths
          borg-backup-test-email
          borg-backup-delete
          borg-backup-restore
          borg-backup-break-lock
          borg-backup-help
          borgTldrPackage
        ]
        ++ lib.optional hasImpermanence borg-backup-btrfs-subvolume;
        # This is needed to link the custom borg-backup tldr page above
        environment.pathsToLink = [ "/share/tldr" ];
        sops.secrets = {
          "keys/ssh/borg" = {
            # FIXME: ATM this is required by nix-darwin PR I'm using
            owner = "root";
            group = if pkgs.stdenv.isLinux then "root" else "wheel";
            path = "${rootHome}/.ssh/id_borg";
          };
        };

        # Other modules need access to files, so add overlay

        nixpkgs.overlays = [
          (final: prev: {
            inherit borg-backup-init borg-backup-paths borg-backup-list;
            borg-tldr-page = borgTldrPackage;
          })
        ];

      }
      # lib.mkIf needed here to avoid infinite recursion
      (lib.mkIf pkgs.stdenv.isLinux {
        # Linux specific
        systemd =
          let
            backupTool = if hasImpermanence then borg-backup-btrfs-subvolume else borg-backup-paths;
            backupToolName = if hasImpermanence then "borg-backup-btrfs-subvolume" else "borg-backup-paths";
            serviceEntries = lib.optionalAttrs cfg.enableService {
              services."borg-backup" = {
                description = "Run ${backupToolName} to backup system";
                after = [ "network-online.target" ];
                wants = [ "network-online.target" ];
                restartIfChanged = false;
                serviceConfig = {
                  Type = "oneshot";
                  ExecStart =
                    pkgs.writeShellScript "borg-backup-inhibited"
                      # bash
                      ''
                        ${pkgs.systemd}/bin/systemd-inhibit \
                                            --why="Backing up data" \
                                            --who="${backupToolName}" \
                                            ${lib.getBin backupTool}/bin/${backupToolName};
                      '';
                  # This is useful for debugging, but not ideal for systemd-inhibit
                  #                  Type = "forking";
                  #                  ExecStart =
                  #                    pkgs.writeShellScript "borg-backup-forking"
                  #                      # bash
                  #                      ''
                  #                        ${lib.getBin backupTool}/bin/${backupToolName} --debug &
                  #                        echo $! > /run/borg-backup.pid
                  #                      '';
                  #                  PIDFile = "/run/borg-backup.pid";
                  RemainAfterExit = false;
                };
              };
              timers."borg-backup" = {
                description = "${backupToolName} backup service";
                wantedBy = [ "timers.target" ];
                requires = [ "network-online.target" ];
                after = [ "network-online.target" ];
                timerConfig = {
                  OnCalendar = "${cfg.borgBackupStartTime}";
                  Persistent = true;
                };
              };
            };
          in
          {
            tmpfiles.rules =
              let
                user = config.users.users.${config.hostSpec.username}.name;
                group = config.users.users.${config.hostSpec.username}.group;
              in
              # https://www.man7.org/linux/man-pages/man5/tmpfiles.d.5.html
              [ "d ${homeDirectory}/mount/backup/ 0750 ${user} ${group} -" ];
          }
          // serviceEntries;

        services = lib.optionalAttrs hasPerNetworkServices {
          per-network-services.trustedNetworkServices = [ "borg-backup" ];
        };
      })
    ]
  );
}
