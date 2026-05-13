{
  lib,
  config,
  pkgs,
  ...
}:
let
  mirror-oath-backups = pkgs.writeShellApplication {
    name = "mirror-oath-backups";
    runtimeInputs = lib.attrValues {
      inherit (pkgs)
        which
        rsync
        openssh
        gnused
        coreutils
        msmtp
        util-linux
        sudo
        systemd
        hostname
        ;
    };

    text =
      # bash
      ''
        export RECIPIENTS=${lib.concatStringsSep ", " config.hostSpec.email.olanAdmins};
        export DELIVERER=${config.hostSpec.email.notifier};
        export SSH_PORT=${toString config.hostSpec.networking.ports.tcp.ssh};
        ${lib.readFile ./mirror-oath-backups.sh}
      '';
  };
in
{
  environment.systemPackages = [
    mirror-oath-backups
  ];

  # Most olan systems backup daily to oath (non-NixOS box). This mirrors those
  # backups to moth. For backing up oath itself, see ./backup-oath.nix.
  #
  # For mirroring backups on NixOS systems, see
  # ../../../modules/hosts/nixos/mirror-backups.nix
  systemd = {
    services."mirror-oath-backups" = {
      description = "Service to periodically mirror oath's backups to moth";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        # NOTE: I'm not sure how important it is to inhibit this since the
        # backup command is actually executing on oath, but I'd still rather
        # avoid it
        ExecStart = # bash
          ''
            ${pkgs.systemd}/bin/systemd-inhibit \
              --why='Mirroring oath\'s backups' \
              --who='Backup Service' \
              --mode=block \
              ${lib.getExe mirror-oath-backups}
          '';
        RemainAfterExit = false;
      };
    };
    timers."mirror-oath-backups" = {
      description = "Timer to trigger mirroring of oath backups";
      wantedBy = [ "timers.target" ];
      after = [ "network-online.target" ];
      requires = [ "network-online.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 2:00:00";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };

}
