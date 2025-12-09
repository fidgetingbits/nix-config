{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [
    inputs.nixos-facter-modules.nixosModules.facter
    { config.facter.reportPath = ./facter.json; }
    ./disks.nix
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
        "mail.nix"

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
    configurationLimit = lib.mkDefault 8;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.availableKernelModules = [ "r8169" ];

  # Allow remote luks unlock over ssh and email admins when the system is ready
  # to unlock
  services.remoteLuksUnlock = {
    enable = true;
    unlockOnly = true;
    notify.to = config.hostSpec.email.olanAdmins;
  };

  services.dyndns = {
    enable = true;
    subDomain = "ogre";
  };

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

  mail-delivery.useRelay = true; # Use o-lan postfix-relay

  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "wake-oppo";
      runtimeInputs = [ pkgs.wakeonlan ];
      text =
        let
          oppo = config.hostSpec.networking.subnets.ogre.hosts.oppo;
        in
        "wakeonlan ${oppo.mac} -i ${oppo.ip}";
    })
  ];

  system.stateVersion = "23.05";
}
