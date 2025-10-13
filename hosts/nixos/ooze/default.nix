{
  lib,
  config,
  ...
}:
{
  imports = [
    #inputs.nixos-hardware.nixosModules.common-gpu-nvidia-sync
    ./hardware-configuration.nix

    # Impermanence
    (lib.custom.relativeToRoot "hosts/common/disks/btrfs-luks-impermanence-disko.nix")
    {
      _module.args = {
        withSwap = true;
      };
    }
  ]
  ++ (map lib.custom.relativeToRoot (
    [
      ##
      # Core
      ##
      "hosts/common/core"
      "hosts/common/core/nixos.nix"
    ]
    ++
      # Optional common modules
      (map (f: "hosts/common/optional/${f}") [
        "keyd.nix"
        "cli.nix"
        "services/openssh.nix"
        "services/atuin.nix"
        "services/atticd.nix"
        "services/postfix-proton-relay.nix"
        "services/unifi.nix" # Unifi Controller
        # For sending mail via backup scripts. Not sure if should just use postfix locally in this case
        "msmtp.nix"

        "acme.nix"
        "remote-builder.nix"

      ])
  ));

  hostSpec = {
    hostName = "ooze";
    isProduction = lib.mkForce true;
    isServer = lib.mkForce true;
    persistFolder = lib.mkForce "/persist";
    useWindowManager = lib.mkForce false;
  };
  system.impermanence.enable = true;

  nixpkgs.config.nvidia.acceptLicense = true;

  services.backup = {
    enable = true;
    borgBackupStartTime = "05:00:00";
  };
  # If we setup postfix, this conflicts
  programs.msmtp.setSendmail = lib.mkForce false;

  # Bootloader.
  boot.loader.systemd-boot = {
    enable = true;
    # When using plymouth, initrd can expand by a lot each time, so limit how many we keep around
    configurationLimit = lib.mkDefault 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.availableKernelModules = [ "r8169" ];
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

  # Override this because we do remote builds
  # FIXME: Double chec this is actually needed anymore
  services.openssh.settings.PermitRootLogin = lib.mkForce "yes";

  # We need IPv6 in order to access hetzner cloud
  #networking.enableIPv6 = true;
  networking.useDHCP = lib.mkDefault true;

  services.heartbeat-check = {
    enable = true;
    interval = 10 * 60;
    hosts = [
      "ottr"
      "ogre"
      "oedo"
      "otto"
      "oath"
      "onus"
    ];
  };

  # Serial cables into lab systems
  # Two of these devices have identical serials, so we need to use the kernel path
  # https://askubuntu.com/questions/49910/how-to-distinguish-between-identical-usb-to-serial-adapters
  # WARNING: If you re-plug the cables, this may break
  services.udev.extraRules = ''
    # ttyUSB0
    ACTION=="add", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="A50285BI", KERNELS=="1-8.1", SYMLINK+="ttyUSB-fang"
    # ttyUSB1
    ACTION=="add", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="A9RAUGOI", SYMLINK+="ttyUSB-flux"
    # ttyUSB2
    ACTION=="add", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="A50285BI", KERNELS=="1-8.3", SYMLINK+="ttyUSB-frog"
    # ttyUSB3
    ACTION=="add", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="A9IPH6E8", SYMLINK+="ttyUSB-frby"
  '';

  system.stateVersion = "23.05";
}
