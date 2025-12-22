{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:
{
  imports = [ inputs.impermanence.nixosModules.impermanence ];

  options.system.impermanence = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable impermanence";
    };
    # FIXME: Actually use this in the script, but need to use the substituteAll approach
    removeTmpFilesOlderThan = lib.mkOption {
      type = lib.types.int;
      default = 14;
      description = "Number of days to keep old btrfs_tmp files";
    };
    autoPersistHomes = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Automatically persist all user's home directories

        This currently assumes you want permission "u=rwx,g=,o=" and
        your user is in "users" group.
      '';
    };
  };

  options.environment = {
    persist = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Files and directories to persist in the home";
    };
  };

  # FIXME(impermanence): Indicate the subvolume to backup
  config = lib.mkIf config.system.impermanence.enable (
    let
      btrfs-diff = pkgs.writeShellApplication {
        name = "btrfs-diff";
        runtimeInputs = lib.attrValues { inherit (pkgs) eza fd btrfs-progs; };
        text = lib.readFile ./btrfs-diff.sh;
      };
    in
    {

      # NOTE: With boot.initrd.systemd.enable = true, we can't use boot.initrd.postDeviceCommands as per
      # https://discourse.nixos.org/t/impermanence-vs-systemd-initrd-w-tpm-unlocking/25167
      # So we build an early stage systemd service, which is modeled after
      # https://github.com/kjhoerr/dotfiles/blob/trunk/.config/nixos/os/persist.nix
      # boot.initrd.postDeviceCommands = lib.mkAfter (lib.readFile ./btrfs_wipe_root.sh);
      # Also see https://github.com/Misterio77/nix-config/blob/main/hosts/common/optional/ephemeral-btrfs.nix
      boot.initrd =
        let
          hostname = config.networking.hostName;
          btrfs-subvolume-wipe-src = lib.readFile ./btrfs-wipe-root.sh;
        in
        {
          supportedFilesystems = [ "btrfs" ];
          systemd.services.btrfs-rollback = {
            description = "Rollback BTRFS root subvolume to a pristine state";
            wantedBy = [ "initrd.target" ];
            after = [
              # NOTE: he \\x2d is a hyphen in the systemd unit name
              "dev-mapper-encrypted\\x2dnixos.device"
              # LUKS/TPM process
              "systemd-cryptsetup@${hostname}.service"
            ];
            before = [ "sysroot.mount" ];
            unitConfig.DefaultDependencies = "no";
            serviceConfig.Type = "oneshot";
            script = btrfs-subvolume-wipe-src;
          };
        };

      fileSystems."${config.hostSpec.persistFolder}".neededForBoot = true;

      # NOTE: This is a list of directories and files that we want to persist across reboots for all systems
      # per-system lists are provided in hosts/<host>/
      environment.persistence."${config.hostSpec.persistFolder}" = {
        hideMounts = true; # Temporary disable for debugging
        directories = (
          lib.flatten (
            [
              "/var/log"
              "/var/lib/bluetooth" # move to bluetooth-specific
              "/var/lib/nixos"
              "/var/lib/systemd/coredump"
              "/etc/NetworkManager/system-connections"

              # systemd DynamicUser requires /var/{lib,cache}/private to exist and be 0700
              # FIXME: I don't entirely understand why this happens sometimes... a service works, then on rebuild
              # it tries to migrate to use a */private/* version and fails because of 755 perms. Then often requires
              # manual 700 modification to fix if I forget to add this first.
              {
                directory = "/var/lib/private";
                mode = "0700";
              }
              {
                directory = "/var/cache/private";
                mode = "0700";
              }

            ]
            ++ lib.optional config.system.impermanence.autoPersistHomes (
              map (user: {
                directory = "${if pkgs.stdenv.isDarwin then "/Users" else "/home"}/${user}";
                inherit user;
                # FIXME: Can't use config.users.users here due to recursion, despite
                # old code using it okay?
                #group = config.users.users.${user}.group;
                group = if pkgs.stdenv.isDarwin then "staff" else "users";
                mode = "u=rwx,g=,o=";
              }) config.hostSpec.users
            )
          )
        );
        files = [
          # Essential. If you don't have these for basic setup, you will have a bad time
          "/etc/machine-id"
          "/etc/ssh/ssh_host_ed25519_key"
          "/etc/ssh/ssh_host_ed25519_key.pub"

          # Non-essential
          "/root/.ssh/known_hosts"
        ];
      };

      programs.fuse.userAllowOther = true;

      environment.systemPackages = [ btrfs-diff ];
    }
  );
}
