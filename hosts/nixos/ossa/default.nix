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

          "startpage.nix"

          # Gaming
          "gaming.nix"

          # "distributed-builds.nix"
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
    borgBackupStartTime = "09:00:00";
  };

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
    # See https://wiki.archlinux.org/title/Intel_graphics
    "dev.i915.perf_stream_paranoid" = 0; # Allow non-root users to access i915 perf streams
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
}
