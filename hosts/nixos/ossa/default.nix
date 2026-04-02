# Asus Zenbook Flip S13 UX371E
{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:
{
  imports = lib.flatten [
    inputs.nixos-hardware.nixosModules.framework-16-amd-ai-300-series
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
          # Host-specific stuff
          "keyd.nix"
          "plymouth.nix"
          "printing.nix"
          "locale.nix"
          "sound.nix"
          # FIXME: Rename this
          "mail-delivery.nix"

          # Desktop environment and login manager
          "sddm.nix"
          "niri.nix"

          # Miscellaneous
          "podman.nix"
          "libvirt.nix"
          "wireshark.nix"
          "cli.nix"
          "yubikey.nix"
          #"iphone-backup.nix"

          # Binary analysis tools
          # "binaryninja.nix"
          # FIXME: Temporary to work around build error on update
          #"cynthion.nix"
          "saleae.nix"

          # Network management
          "systemd-resolved.nix"

          # Remote network mounts and syncing
          "services/syncthing.nix"

          # "startpage.nix"

          # Gaming
          "gaming.nix"

          "distributed-builds.nix"
          "fonts.nix"

          "logind.nix"
        ])
    ))
  ];

  # FIXME: Hack. This is because something creates /home/aa/mount as root after install
  # and I dunno what
  systemd.tmpfiles.rules = [
    "d    /home/${config.hostSpec.username}/mount    0700    ${config.hostSpec.username}    users    -    -"
  ];

  wifi = {
    enable = true;
    roaming = config.hostSpec.isRoaming;
  };

  # Just set the console font, don't mess with the font settings
  #console.font = lib.mkDefault "${pkgs.terminus_font}/share/consolefonts/ter-v32n.psf.gz";
  console.earlySetup = lib.mkDefault true;

  # Enable swap on luks
  boot.initrd.systemd.enable = true;
  boot.supportedFilesystems = [ "ntfs" ];

  # Keyring, required for auth even without gnome
  # FIXME: double check this
  security.pam.services.sddm.enableGnomeKeyring = true;
  modules.hardware.radeon.enable = true;

  environment.systemPackages = lib.attrValues {
    inherit (pkgs)
      # gnupg - see yubikey.nix
      paperkey # printed gpg key backup utilitie
      pinentry-curses # for gpg-agent
      pinentry-gtk2 # for gpg-agent
      ;
  };
  services.fwupd.enable = true;
  services.backup = {
    enable = true;
    borgBackupStartTime = "*-*-* 03:00:00";
  };

  services.remoteLuksUnlock = {
    enable = true;
    notify.to = config.hostSpec.email.olanAdmins;
  };
  system.impermanence.enable = true;

  #  virtualisation.appvm = {
  #    enable = true;
  #    user = config.hostSpec.primaryUsername;
  #  };

  # Bluetooth
  services.blueman.enable = true;

  # FIXME: Move this to a ccache module
  programs.ccache.enable = true;
  nix.settings.extra-sandbox-paths = [ config.programs.ccache.cacheDir ];
  environment.persistence.${config.hostSpec.persistFolder}.directories =
    lib.mkIf config.system.impermanence.enable
      [
        # CCache
        (lib.mkIf config.programs.ccache.enable {
          directory = config.programs.ccache.cacheDir;
          user = "root";
          group = "nixbld";
          mode = "u=,g=rwx,o=";
        })
      ];

}
