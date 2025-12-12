# Beelink EQR5
{
  inputs,
  lib,
  ...
}:
{
  imports = lib.flatten [
    inputs.adblock-hosts.nixosModule
    inputs.nixos-facter-modules.nixosModules.facter
    { config.facter.reportPath = ./facter.json; }
    ./disks.nix

    (map lib.custom.relativeToRoot (
      [
        "hosts/common/core"
        "hosts/common/core/nixos.nix"
      ]
      ++
        # Optional common modules
        (map (f: "hosts/common/optional/${f}") [
          # Desktop environment and login manager
          "sddm.nix"
          "gnome.nix"

          # Services
          "services/blocky.nix" # Ad Blocking DNS
          "services/unifi.nix" # Unifi Controller
          "services/xrdp.nix" # Remote Desktop

          # Network management
          "systemd-resolved.nix"

          # Misc
          "mail.nix"
          "plymouth.nix" # Boot graphics
          "sound.nix"
          "cli.nix"
          "fonts.nix"
          "logind.nix"
        ])
    ))
  ];

  # Turn off nginx reverse proxy
  services.unifi.useProxy = lib.mkForce false;
  services.dyndns.enable = true;

  # Host Specification
  hostSpec = {
    hostName = "moon";
    users = lib.mkForce [
      "admin"
      "ca"
    ];
    primaryUsername = lib.mkForce "admin";
    primaryDesktopUsername = lib.mkForce "ca";
    # FIXME: deprecate this
    username = lib.mkForce "admin";

    # System type flags
    isWork = lib.mkForce false;
    isProduction = lib.mkForce true;
    isRemote = lib.mkForce true;

    # Functionality
    # FIXME: Separate this out to allow yubikey for incoming auth but not physical yubikey plugged in
    useYubikey = lib.mkForce false;
    useNeovimTerminal = lib.mkForce true;
    useAtticCache = lib.mkForce false;

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

  wifi = {
    enable = true;
    wlans = [ "moon" ];
  };

  system.impermanence.enable = true;

  boot.initrd.systemd.enable = true;

  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false;
  networking.useDHCP = lib.mkDefault true;
  networking.dhcpcd.wait = "background";
  services.gnome.gnome-keyring.enable = true;

  # Keyring, required for auth even without gnome
  security.pam.services.sddm.enableGnomeKeyring = true;

  # Auto-login as regular user
  services.displayManager.autoLogin = {
    user = lib.mkForce "ca";
  };
  services.displayManager.sddm.autoLogin = {
    relogin = true;
  };

  services.logind = {
    settings.Login.HandlePowerKey = lib.mkForce "reboot";
  };

  # FIXME:
  # services.backup = {
  #   enable = true;
  #   borgBackupStartTime = "09:00:00";
  # };

  sops = {
    secrets = {
      "keys/ssh/ed25519" = {
        # User/group created by the autosshTunnel module
        owner = "autossh";
        group = "autossh";
        path = "/etc/ssh/id_ed25519";
      };
      "keys/ssh/ed25519_pub" = {
        owner = "autossh";
        group = "autossh";
        path = "/etc/ssh/id_ed25519.pub";
      };
    };
  };

  tunnels.cakes.enable = true;

  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ]; # Apply to all keyboards
      settings = {
        main = {
          mute = "noop";
          volumedown = "noop";
          volumeup = "noop";
        };
      };
    };
  };

  # Add ad-blocking to hosts file
  networking.stevenBlackHosts.enable = true;
}
