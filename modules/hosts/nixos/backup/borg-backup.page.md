        # borg-backup

        > Custom backup toolset using borg. See `borg-backup-help` for argument overrides

        - List all existing archives in the repository:
          `borg-backup-list`

        - List all existing archives in the repository, for a different host:
          bash:
          `read -s -p "Passphrase:" BORG_PASSPHRASE && BORG_HOST=oedo borg-backup-list`
          zsh:
          `read -rs "BORG_PASSPHRASE?Passphrase:" && BORG_HOST=oedo borg-backup-list`

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
