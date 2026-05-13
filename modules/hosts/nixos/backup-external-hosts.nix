# IMPORTANT: This module is used to backup Synology NAS mounts declaratively. Some paths
# are still hard-coded based off that assumption.
{
  inputs,
  pkgs,
  lib,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.backup-external-host;
  hostSpec = config.hostSpec;
in
{
  options.${namespace}.backup-external-host = {
    enable = lib.mkEnableOption ''
      Enable borg-based backup of some external host's data that is mounted onto the
      primary host. It works by wrapping backup tools already enabled to back
      up the primary host.

      IMPORTANT: This module builds off of config.services.backup settings, so
      its defaults are used as a baseline for the tools run here. It currently
      re-uses the passphrase for backing up the primary host, to encrypt the
      external host data.

      This modules purpose is to allow declarative backup settings for
      non-declarative systems, at the cost of some additional network activity.

      For a script to orchestrate backing up data from one non-NixOS system to another,
      see long-rsync. Something like that could also be done instead of this module.
    '';

    # FIXME: This is gross if cifs-mount is also used elsewhere...
    secretsFile = lib.mkOption {
      type = lib.types.str;
      default = (toString inputs.nix-secrets) + "/sops/olan.yaml";
      description = "Secret file containing creds for mounting host being backed up up";
    };

    hosts = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule (
          # NOTE: config here is the submodule option values at eval time
          { config, ... }:
          {
            options = {
              host = lib.mkOption {
                type = lib.types.str;
                description = "Remote host being backed up";
              };

              server = lib.mkOption {
                type = lib.types.str;
                description = "The remote host storing the backup";
              };

              mountPath = lib.mkOption {
                type = lib.types.str;
                description = "Mount path of data being backed up from host";
              };

              folders = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                description = "List of paths to backup, relative to mountPath (${config.mountPath})";
              };

              user = lib.mkOption {
                type = lib.types.str;
                default = hostSpec.primaryUsername;
                description = "Owner of the backup, dictating the path";
              };

            };
          }
        )
      );
      description = "List of NAS to backup";
    };
  };

  # Can't use lib.mkMerge due to infinite recursion, so for now do per-entry maps.
  # Probably a better way?
  config = lib.mkIf cfg.enable (
    let
      hostTools = lib.mergeAttrsList (
        map (entry: {
          ${entry.host} =
            let
              inherit (entry) host user;
              commonEnvironment = # bash
                ''
                  export BORG_HOST="${host}"
                  export BORG_SERVER="${entry.server}"
                  # FIXME: These should be options? They mirror backup, but we have to?
                  # Backing up to a nixos box
                  export BORG_REMOTE_PATH="/run/current-system/sw/bin/borg"
                  # Backup path on said nix box
                  export BORG_REMOTE_REPO="/mnt/storage/backup/${user}/${host}"
                '';
            in
            {
              backup-host = pkgs.writeShellApplication {
                name = "backup-${entry.host}";
                runtimeInputs = lib.attrValues {
                  inherit (pkgs)
                    borg-backup-paths
                    ;
                };

                text =
                  let
                    path = entry.mountPath;
                  in
                  # bash
                  ''
                    ${commonEnvironment}
                    export BORG_BACKUP_PATHS="${
                      entry.folders
                      |> lib.map (n: "${path}/${n}")
                      # nixfmt hack
                      |> lib.concatStringsSep " "
                    }"
                    BORG_BACKUP_NAME="$BORG_HOST-$(date +%Y-%m-%d_%H-%M)"
                    export BORG_BACKUP_NAME
                    borg-backup-paths
                  '';
              };
              # Since manually overriding the env is annoying, we provide some
              # helpers
              backup-list = pkgs.writeShellApplication {
                name = "${host}-backup-list";
                runtimeInputs = lib.attrValues {
                  inherit (pkgs)
                    borg-backup-paths
                    ;
                };
                text = # bash
                  ''
                    ${commonEnvironment}
                    borg-backup-list
                  '';
              };

              # Helper in case you need to run some host-specific backup
              # commands and don't want to remember what variables to set
              hostEnvironment =
                pkgs.writeText "${host}-setenv.sh"
                  # bash
                  ''
                    ${commonEnvironment}
                  '';
            };
        }) cfg.hosts
      );
    in
    {
      systemd = lib.mkMerge (
        map (
          hostConf:
          let
            inherit (hostConf) host;
          in
          {
            services."backup-${host}" = {
              description = "Service to periodically backup ${host} data";
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];
              serviceConfig = {
                ExecStart = lib.getExe hostTools.${host}.backup-host;
                RemainAfterExit = false;
              };
            };
            timers."backup-${host}" = {
              description = "Timer to trigger backup of ${host} data";
              wantedBy = [ "timers.target" ];
              after = [ "network-online.target" ];
              requires = [ "network-online.target" ];
              timerConfig = {
                OnCalendar = "*-*-* 3:00:00";
                Persistent = true;
                RandomizedDelaySec = "1h";
              };
            };
          }
        ) cfg.hosts
      );

      # FIXME: Option to say to use cifs or nfs
      # Also the secretsFile is gross
      # NOTE: Better to add any additional backup-host-specific options
      # external to this module vs mirror more options
      ${namespace}.cifs-mounts = {
        enable = true;
        sopsFile = cfg.secretsFile;
        mounts = map (entry: { name = entry.host; }) cfg.hosts;
      };

      environment.systemPackages = lib.flatten (
        map (entry: [
          hostTools.${entry.host}.backup-host
          hostTools.${entry.host}.backup-list
        ]) cfg.hosts
      );

      assertions = [
        {
          assertion = config.services.backup.enable;
          message = "The config.services.backup service must be enabled in order to backup external hosts, as the configs are related.";
        }
      ];
    }
  );
}
