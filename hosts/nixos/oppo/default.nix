{
  lib,
  pkgs,
  ...
}:
{
  imports = lib.flatten [
    ./hardware-configuration.nix

    (map lib.custom.relativeToRoot [
      "hosts/common/core"
      "hosts/common/core/nixos.nix"

      # Host-specific stuff
      #"hosts/common/optional/msmtp.nix"
      "hosts/common/optional/plymouth.nix"
      "hosts/common/optional/locale.nix"
      #"hosts/common/optional/wayland.nix"
      "hosts/common/optional/sound.nix"

      # Desktop environment and login manager
      "hosts/common/optional/gdm.nix"
      #"hosts/common/optional/greetd.nix"
      #"hosts/common/optional/hyprland.nix"
      "hosts/common/optional/gnome.nix"

      #"hosts/common/optional/podman.nix"
      #"hosts/common/optional/libvirt.nix"
      "hosts/common/optional/cli.nix"
      "hosts/common/optional/yubikey.nix"
      "hosts/common/optional/services/openssh.nix"

      # Network management
      "hosts/common/optional/systemd-resolved.nix"

      # Remote network mounts and syncing
      #"hosts/common/optional/mounts/oath-cifs.nix"
      #"hosts/common/optional/services/syncthing.nix"

      # Gaming
      #"hosts/common/optional/gaming.nix"
    ])
    # Impermanence
    (lib.custom.relativeToRoot "hosts/common/disks/btrfs-luks-impermanence-disko.nix")
    {
      _module.args = {
        disk = "/dev/nvme0n1";
        withSwap = true;
      };
    }

  ];

  # Host Specification
  hostSpec = {
    # Read current directory to get the host name
    hostName = "oppo";
    isWork = lib.mkForce false;
    voiceCoding = lib.mkForce false;
    useYubikey = lib.mkForce true;
    isAutoStyled = lib.mkForce true;
    wifi = lib.mkForce false;
    useNeovimTerminal = lib.mkForce true;
    hdr = lib.mkForce false;
    #scaling = lib.mkForce "2";
    isProduction = lib.mkForce true;
    useAtticCache = lib.mkForce false;
    isDevelopment = lib.mkForce true;
    persistFolder = lib.mkForce "/persist";

  };
  system.impermanence.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  # Bootloader.
  boot.loader.systemd-boot = {
    enable = true;
    # When using plymouth, initrd can expand by a lot each time, so limit how many we keep around
    configurationLimit = lib.mkDefault 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # Just set the console font, don't mess with the font settings
  #console.font = lib.mkDefault "${pkgs.terminus_font}/share/consolefonts/ter-v32n.psf.gz";
  console.earlySetup = lib.mkDefault true;

  networking.networkmanager.enable = true;
  networking.useDHCP = lib.mkDefault true;

  # Keyring, required for auth even without gnome
  security.pam.services.sddm.enableGnomeKeyring = true;

  environment.systemPackages = builtins.attrValues {
    inherit (pkgs)
      # gnupg - see yubikey.nix
      paperkey # printed gpg key backup utilitie
      pinentry-curses # for gpg-agent
      pinentry-gtk2 # for gpg-agent
      ;
  };
  services.fwupd.enable = true;
  #services.backup = {
  #  enable = true;
  #  borgBackupStartTime = "09:00:00";
  #};

  #networking.granularFirewall.enable = true;

  system.stateVersion = "23.05";
}
