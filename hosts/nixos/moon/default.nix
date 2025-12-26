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
    (lib.custom.scanPaths ./.) # Load all extra host-specific *.nix files

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
          "mail-delivery.nix"
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
