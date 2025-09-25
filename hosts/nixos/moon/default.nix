# Beelink EQR5
{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = lib.flatten [
    inputs.nixos-facter-modules.nixosModules.facter
    { config.facter.reportPath = ./facter.json; }
    (lib.custom.relativeToRoot "hosts/common/disks/btrfs-impermanence-disko.nix")
    {
      _module.args = {
        withSwap = true;
      };
    }

    (map lib.custom.relativeToRoot (
      [
        "hosts/common/core"
        "hosts/common/core/nixos.nix"
      ]
      ++
        # Optional common modules
        (map (f: "hosts/common/optional/${f}") [
          # Host-specific stuff
          "msmtp.nix"
          "plymouth.nix"
          "sound.nix"

          # Desktop environment and login manager
          # FIXME: Tweak this for moon
          "sddm.nix"
          "gnome.nix"

          "cli.nix"
          "yubikey.nix"
          "services/openssh.nix"

          # Network management
          "systemd-resolved.nix"

          "fonts.nix"
        ])
    ))
  ];

  # Host Specification
  hostSpec = {
    hostName = "moon";
    users = lib.mkForce [
      "admin"
      "ca"
    ];
    primaryUsername = lib.mkForce "admin";
    # FIXME: deprecate this
    username = lib.mkForce "admin";

    isWork = lib.mkForce false;
    isProduction = lib.mkForce true;

    voiceCoding = lib.mkForce false;
    useYubikey = lib.mkForce true;
    wifi = lib.mkForce true;
    useNeovimTerminal = lib.mkForce true;

    # Graphical
    defaultDesktop = "gnome";
    useWayland = lib.mkForce true;
    hdr = lib.mkForce true;
    scaling = lib.mkForce "2";
    isAutoStyled = lib.mkForce true;
    wallpaper = "${inputs.nix-assets}/images/wallpapers/botanical_garden.webp";
    persistFolder = lib.mkForce "/persist";
    timeZone = lib.mkForce "America/Edmonton";
  };

  system.impermanence.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  # Bootloader.
  boot.loader.systemd-boot = {
    enable = true;
    # When using plymouth, initrd can expand by a lot each time, so limit how many we keep around
    configurationLimit = lib.mkDefault 10;
    consoleMode = "1";
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;

  # We need IPv6 in order to access hetzner cloud systems
  networking.networkmanager.enable = true;
  networking.useDHCP = lib.mkDefault true;
  networking.dhcpcd.wait = "background";
  systemd.network.wait-online.enable = false;
  services.gnome.gnome-keyring.enable = true;

  # Keyring, required for auth even without gnome
  security.pam.services.sddm.enableGnomeKeyring = true;

  # Auto-login as regular user
  services.displayManager.sddm.autoLogin = {
    user = lib.mkForce "ca";
    relogin = true;
  };

  # FIXME:
  # services.backup = {
  #   enable = true;
  #   borgBackupStartTime = "09:00:00";
  # };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = "23.05";
}
