{
  inputs,
  lib,
  pkgs,
  config,
  namespace,
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
          "printing.nix"
          "locale.nix"
          "sound.nix"

          "icons.nix"

          # Miscellaneous
          "podman.nix"
          # "libvirt.nix"
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
          "opensnitch.nix"

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

  introdus = {
    niri.enable = true;
    plymouth.enable = true;
  };

  # FIXME: Does this need to be name spaced?
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

      fw-ectool # FW16 fan speed, charge limit
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
    lib.mkIf config.introdus.impermanence.enable
      [
        # CCache
        (lib.mkIf config.programs.ccache.enable {
          directory = config.programs.ccache.cacheDir;
          user = "root";
          group = "nixbld";
          mode = "u=,g=rwx,o=";
        })
      ];

  # From here:
  # https://community.frame.work/t/no-sound-from-speaker-but-audio-expansion-module-and-bluetooth-headphones-works-how-to-troubleshoot/79259/4
  # Not sure if it's because of facter.json or what but, speaker wasn't set to default. pavucontrol
  # and wpctl status showed tons of Ryzen HD Audio entries, but no speaker sound would work. After
  # enabling/unmuting HiFi (Mic1, Mic2, Speaker) via alsamixer, the problem went away, and the entries in
  # pavucontrol/noctalia are now sane.
  services.pipewire.wireplumber = {
    enable = true;
    extraConfig.speakerProfile = {
      "monitor.alsa.rules" = [
        {
          matches = [ { "device.name" = "alsa_card.pci-0000_c1_00.6"; } ];
          actions = {
            "update-props" = {
              "device.profile" = "HiFi (Mic1, Mic2, Speaker)";
            };
          };
        }
      ];
    };
  };

  systemd.user.services.xdg-desktop-portal = {
    overrideStrategy = "asDropin";
    unitConfig = {
      Wants = [ "xdg-desktop-portal-gnome.service" ];
      After = [ "xdg-desktop-portal-gnome.service" ];
    };
  };

  networking.granularFirewall.enable = true;

  # Only exposed to microvms, which is handled via allowedPorts in
  # modules/hosts/nixos/microvms/network.nix rather than
  # granularFirewall, as don't have way to specify interface yet
  ${namespace} = {
    services.llama-swap = {
      enable = true;
      # Limit models to those that suit local Strix Point use
      # See models set in modules/hosts/nixos/llama-swap.nix for full list
      # models = [
      #   "fim:qwen-1.5b"
      #   "gemma-4:26b-a4b-q6"
      #   "qwen3.6:coder-30b-a3b-q6"
      # ];
    };
  };

  # See:
  #  https://www.jeffgeerling.com/blog/2025/increasing-vram-allocation-on-amd-ai-apus-under-linux/
  #  https://github.com/ROCm/ROCm/issues/5562#issuecomment-3452179504
  #  https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/install/installryz/native_linux/install-ryzen.html#configure-shared-memory
  #  https://blog.linux-ng.de/2025/07/13/getting-information-about-amd-apus/
  #
  # You can allegedly use newer amd-smi options to manually set this as well:
  # https://github.com/ROCm/rocm-systems/pull/3636
  boot.kernelParams =
    let
      # 96 GiB - 32 GiB = 64 GiB
      sz = toString ((64 * 1024 * 1024 * 1024) / 4096);
    in
    [
      "amd_iommu=off" # disables VFIO for local llm speed
      "amdttm.pages_limit=${sz}"
      "amdttm.page_pool_size=${sz}"
      "ttm.pages_limit=${sz}"
      "ttm.page_pool_size=${sz}"
    ];
}
