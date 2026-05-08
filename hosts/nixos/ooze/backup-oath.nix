{
  inputs,
  pkgs,
  lib,
  config,
  namespace,
  ...
}:
let
  # This is a wrapper around borg-backup-paths that allows us to backup folders
  # from the nas, but from ooze. This allows us to be more declarative,
  # at the expense of some extra network ping pong. But I don't want to
  # maintain scripts on the NAS itself anymore.
  #
  # This relies on having the NAS share mounted via cifs/nfs. Otherwise we can
  # mostly rely on local settings. We also are backing up oath, so we override
  # to backup to moth instead
  backup-oath = pkgs.writeShellApplication {
    name = "backup-oath";
    runtimeInputs = lib.attrValues {
      # This is globally installed via backups, but need to put it into pkgs I guess
      inherit (pkgs)
        borg-backup-paths
        ;
    };

    # NOTE: For convenience we just re-use the passphrase for oath/ooze backup
    text =
      let
        user = config.hostSpec.primaryUsername;
        server = "oath";
        path = "/home/${user}/mount/oath/";
        folders = [ "logs" ]; # Folders inside path that we want to backup
      in
      # bash
      ''
        export BORG_HOST="${server}"
        export BORG_SERVER="moth"
        export BORG_BACKUP_PATHS=${
          folders
          |> lib.map (n: "${path}")
          # nixfmt hack
          |> lib.concatStringsSep " "
        }
        export BORG_BACKUP_NAME
        BORG_BACKUP_NAME="$BORG_HOST-$(date +%Y-%m-%d_%H-%M)"
        export BORG_REMOTE_PATH="/run/current-system/sw/bin/borg"
        export BORG_REMOTE_REPO="/mnt/storage/backup/${user}/${server}"
        borg-backup-paths
      '';
  };
  # FIXME: Need wrappers to more easily list/mount the oath backups too

in
{

  environment.systemPackages = [
    backup-oath
  ];

  ${namespace} = {
    # In order to backup oath from a nix box, we need to mount it
    cifs-mounts = {
      enable = true;
      sopsFile = (toString inputs.nix-secrets) + "/sops/olan.yaml";
      mounts = [
        {
          name = "oath";
        }
      ];
    };
  };

  systemd = {
    services."backup-oath" = {
      description = "Service to periodically backup oath data";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = lib.getExe backup-oath;
        RemainAfterExit = false;
      };
    };
    timers."backup-oath" = {
      description = "Timer to trigger backup of oath data";
      wantedBy = [ "timers.target" ];
      after = [ "network-online.target" ];
      requires = [ "network-online.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 3:00:00";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };

}
