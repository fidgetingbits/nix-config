# Beelink EQR5
{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:
{
  imports = lib.flatten [
    inputs.nixos-facter-modules.nixosModules.facter
    { config.facter.reportPath = ./facter.json; }
    ./disko.nix

    (map lib.custom.relativeToRoot (
      [
        "hosts/common/core"
        "hosts/common/core/nixos.nix"
      ]
      ++
        # Optional common modules
        (map (f: "hosts/common/optional/${f}") [
          # Services
          "services/openssh.nix"
          "services/ddclient.nix"

          # Network management
          "systemd-resolved.nix"

          # Misc
          # "msmtp.nix" # FIXME: We only need this if we setup emails for logins/backups, etc
          "logind.nix"
          "cli.nix"
        ])
    ))
  ];

  # Host Specification
  hostSpec = {
    hostName = "myth";
    users = lib.mkForce [
      "admin"
      "pa"
    ];
    primaryUsername = lib.mkForce "admin";
    # FIXME: deprecate this
    username = lib.mkForce "admin";

    # System type flags
    isWork = lib.mkForce false;
    isProduction = lib.mkForce true;
    isRemote = lib.mkForce true;
    isServer = lib.mkForce true;
    isAutoStyled = lib.mkForce false;
    useWindowManager = lib.mkForce false;

    # Functionality
    voiceCoding = lib.mkForce false;
    useYubikey = lib.mkForce false;
    useNeovimTerminal = lib.mkForce false;
    useAtticCache = lib.mkForce false;

    # Networking
    wifi = lib.mkForce false;

    # Sysystem settings
    persistFolder = lib.mkForce "/persist";
    timeZone = lib.mkForce "America/Edmonton";
  };

  system.impermanence.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  # Bootloader
  boot.loader.systemd-boot = {
    enable = true;
    # Needs to be lowered if we ever run plymouth
    configurationLimit = lib.mkDefault 30;
    consoleMode = "1";
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # NOTE: I removed wlo1 entirely from facter.json since the below didn't work,
  # but leaving it in.
  # Disable wlo1 completely since we aren't using wifi
  # boot.blacklistedKernelModules = [
  #   "iwlwifi"
  # ];
  # networking.interfaces.wlo1.useDHCP = false;
  # systemd.network.netdevs.wlo1.enable = false;

  # Remote early boot LUKS unlock via ssh
  boot.initrd = {
    systemd = {
      enable = true;
      # emergencyAccess = true;
      users.root.shell = "/bin/systemd-tty-ask-password-agent";
    };
    luks.forceLuksSupportInInitrd = true;
    # Setup the host key as a secret in initrd, so it's not exposed in the /nix/store
    # this is all too earlier for sops
    secrets = lib.mkForce { "/etc/secrets/initrd/ssh_host_ed25519_key" = ./initrd_ed25519_key; };
    network = {
      enable = true;
      ssh = {
        enable = true;
        port = config.hostSpec.networking.ports.tcp.ssh;
        authorizedKeys = config.users.users.${config.hostSpec.username}.openssh.authorizedKeys.keys;
        hostKeys = [ "/etc/secrets/initrd/ssh_host_ed25519_key" ];
      };
    };
  };

  # NOTE: This triggers a warning about /usr/lib/mdadm/mdadm_env.sh not existing, which is part of
  # the ExecStartPre, but is benign
  # FIXME: Is mdchecks better for this?
  systemd.services."mdmonitor".environment = {
    MDADM_MONITOR_ARGS = "--scan --syslog";
  };

  services.logind.powerKey = lib.mkForce "reboot";

  # needed to unlock LUKS on raid drives
  # https://wiki.nixos.org/wiki/Full_Disk_Encryption#Unlocking_secondary_drives
  # lsblk -o name,uuid,mountpoints
  environment.persistence."${config.hostSpec.persistFolder}" = {
    files = [
      "/luks-secondary-unlock.key"
    ];
  };

  # NOTE: Using /dev/disk/by-partlabel/ would be nicer than UUID, however because we are using raid5, there is no
  # single partlabel to use, we need the UUID assigned to the raid5 device created by mdadm (/dev/md127)
  # FIXME: See if the secondary-unlock key can actually be part of sops, which would be possible if
  # systemd-cryptsetup@xxx.service runs after sops service
  # https://github.com/ckiee/nixfiles/blob/aa0138bc4b183d939cd8d2e60bcf2828febada36/hosts/pansear/hardware.nix#L16
  # We may need to make our own systemd unit that tries to mount but that isn't critical, so that we can ignore it
  # in the event of an error (like if you forget to update the UUID after bootstrap, etc).
  # Not bothering for now, as it's not pressing. The drives are already using the same passphrase as the main drive, which we have recorded
  environment.etc.crypttab.text = lib.optionalString (!config.hostSpec.isMinimal) ''
    encrypted-storage UUID=ff3207ca-0af8-4dc3-a21f-4ec815b57c56 /luks-secondary-unlock.key nofail,x-systemd.device-timeout=10
  '';

  # FIXME:
  # services.backup = {
  #   enable = true;
  #   borgBackupStartTime = "09:00:00";
  # };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = "23.05";
}
