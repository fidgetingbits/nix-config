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
          "x11.nix"
          "sound.nix"
          # FIXME: Rename this
          "mail-delivery.nix"

          # Desktop environment and login manager
          # "gdm.nix"
          "sddm.nix"
          "gnome.nix"
          "i3wm.nix"
          "niri.nix"

          # Miscellaneous
          "podman.nix"
          "libvirt.nix"
          "wireshark.nix"
          "cli.nix"
          "yubikey.nix"
          "thunar.nix"
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

          "startpage.nix"

          # Gaming
          "gaming.nix"

          "distributed-builds.nix"
          "fonts.nix"

          "logind.nix"
        ])
    ))
  ];

  # FIXME: Further tweak this
  desktops.hyprland.enable = true;

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
    borgBackupStartTime = "03:00:00";
  };

  system.impermanence.enable = true;

  # For explanations of these options, see
  # https://github.com/CryoByte33/steam-deck-utilities/blob/main/docs/tweak-explanation.md
  boot.kernel.sysctl = {
    # Was getting crazy cpu stuttering from kcompactd0 which this seems to largely fix
    "vm.compaction_proactiveness" = 0;
    "vm.extfrag_threshold" = 1000;
    # This is to stop kswapd0 which noticably stuttered after kcompactd0 lag went away
    "vm.swappiness" = 1;
    "vm.page_lock_unfairness" = 1;
    "mm.transparent_hugepage.enabled" = "always";
  };
  # Others noted khugepaged causes issues after the above was disabled, so also disabling that.
  system.activationScripts.sysfs.text = ''
    echo advise > /sys/kernel/mm/transparent_hugepage/shmem_enabled
    echo never > /sys/kernel/mm/transparent_hugepage/defrag
    echo 0 > /sys/kernel/mm/transparent_hugepage/khugepaged/defrag
  '';

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

  #  Framework 16 is super unreliable on 6.18.x it seems (unless it's hardware issues)
  boot.kernelPackages = lib.mkForce (
    pkgs.linuxPackagesFor (
      # Note: the override has to be for a package that exists, thus 6.18
      pkgs.linux_6_18.override {
        argsOverride = rec {
          src = pkgs.fetchurl {
            url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
            sha256 = "sha256-EWgC3DrRZGFjzG/+m926JKgGm1aRNewFI815kGTy7bk=";
          };
          version = "6.17.13";
          modDirVersion = "6.17.13";
        };
      }
    )
  );
}
