# Asus Zenbook Flip S13 UX371E
{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:
rec {
  imports = lib.flatten [
    #inputs.nixos-hardware.nixosModules.asus-zenbook-ux371
    # NOTE: I still use this because I have the hardcoded disks, which should move out I guess
    ./hardware-configuration.nix
    inputs.nixos-facter-modules.nixosModules.facter
    { config.facter.reportPath = ./facter.json; }

    (map lib.custom.relativeToRoot (
      [
        "hosts/common/core"
        "hosts/common/core/nixos.nix"
        # FIXME: Make this an enable
        "modules/hosts/common/hyprland.nix"
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
          "mail.nix"

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
          "tobii.nix"
          "services/openssh.nix"
          #"iphone-backup.nix"

          # Binary analysis tools
          "binaryninja.nix"
          # FIXME: Temporary to work around build error on update
          #"cynthion.nix"
          "saleae.nix"

          # Network management
          "systemd-resolved.nix"

          # Remote network mounts and syncing
          "mounts/oath-cifs.nix"
          "mounts/onus-cifs.nix"
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

  # Host Specification
  hostSpec = {
    hostName = "onyx";
    isWork = lib.mkForce true;
    voiceCoding = lib.mkForce false;
    useYubikey = lib.mkForce true;
    useWayland = lib.mkForce true;
    useWindowManager = lib.mkForce true;
    isAutoStyled = lib.mkForce true;
    useNeovimTerminal = lib.mkForce true;
    hdr = lib.mkForce true;
    scaling = lib.mkForce "2";
    isProduction = lib.mkForce true;
    useAtticCache = lib.mkForce true;
    isDevelopment = lib.mkForce true;
    isRoaming = lib.mkForce true;
    users = lib.mkForce [
      "aa"
      #"media"
    ];
    wallpaper = "${inputs.nix-assets}/images/wallpapers/astronaut.webp";
    defaultDesktop = "hyprland-uwsm";
    persistFolder = lib.mkForce "";
    timeZone = lib.mkForce "America/Edmonton";
  };

  wifi = {
    enable = true;
    roaming = config.hostSpec.isRoaming;
  };

  mail-delivery = {
    enable = true;
  };

  # Bootloader
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = lib.mkDefault 10;
    consoleMode = "1";
  };

  boot.loader.efi.canTouchEfiVariables = true;

  # Just set the console font, don't mess with the font settings
  #console.font = lib.mkDefault "${pkgs.terminus_font}/share/consolefonts/ter-v32n.psf.gz";
  console.earlySetup = lib.mkDefault true;

  # Setup keyfile
  boot.initrd.secrets = {
    "/crypto_keyfile.bin" = null;
  };

  # Enable swap on luks
  boot.initrd.luks.devices."luks-e2232963-327f-4833-9bcc-5e5a8dae9551".device =
    "/dev/disk/by-uuid/e2232963-327f-4833-9bcc-5e5a8dae9551";
  boot.initrd.luks.devices."luks-e2232963-327f-4833-9bcc-5e5a8dae9551".keyFile =
    "/crypto_keyfile.bin";
  boot.initrd.systemd.enable = true;
  boot.supportedFilesystems = [ "ntfs" ];

  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false;
  networking.useDHCP = lib.mkDefault true;
  # We need IPv6 in order to access hetzner cloud systems
  #networking.enableIPv6 = true;

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
  voiceCoding.enable = false;
  services.backup = {
    enable = true;
    borgBackupStartTime = "09:00:00";
    # This is only relevant while I'm not using btrfs subvolume backup
    borgExcludes = [ "${config.hostSpec.home}/movies" ];
  };

  services.per-network-services =
    let
      # Define what trusted networks looks like for this system
      oryx = {
        type = "wireless";
        ssid = "oryx";
        interface = "wlo1";
        gateway = inputs.nix-secrets.networking.subnets.ogre.hosts.oryx.ip;
        mac = inputs.nix-secrets.networking.subnets.ogre.hosts.oryx.mac;
      };
      ogre = {
        type = "wired";
        domain = inputs.nix-secrets.domain;
        interface = "";
        gateway = inputs.nix-secrets.networking.subnets.ogre.hosts.ogre.ip;
        mac = inputs.nix-secrets.networking.subnets.ogre.hosts.ogre.mac;
      };
    in
    {
      enable = true;
      debug = true; # FIXME(onyx): Remove this
      # FIXME: This should be synchronized with the code that renames it
      networkDevices = [ "wlo1" ];
      trustedNetworks = [
        oryx
        ogre
      ];
    };
  networking.granularFirewall.enable = true;

  system.stateVersion = "23.05";

  # For explanations of these options, see
  # https://github.com/CryoByte33/steam-deck-utilities/blob/main/docs/tweak-explanation.md
  boot.kernel.sysctl = {
    # Was getting crazy cpu stuttering from kcompactd0 which this seems to  largely fix
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

  # OOM configuration (https://discourse.nixos.org/t/nix-build-ate-my-ram/35752)
  # FIXME: Make this generic eventually
  systemd = {
    # Create a separate slice for nix-daemon that is
    # memory-managed by the userspace systemd-oomd killer
    slices."nix-daemon".sliceConfig = {
      ManagedOOMMemoryPressure = "kill";
      ManagedOOMMemoryPressureLimit = "50%";
    };
    services."nix-daemon".serviceConfig.Slice = "nix-daemon.slice";

    # If a kernel-level OOM event does occur anyway,
    # strongly prefer killing nix-daemon child processes
    services."nix-daemon".serviceConfig.OOMScoreAdjust = 1000;
  };
  # Use 50% of cores to try to reduce memory pressure
  nix.settings.cores = lib.mkDefault 2; # FIXME: Can we use nixos-hardware to know the core count?
  nix.settings.max-jobs = lib.mkDefault 2;
  nix.daemonCPUSchedPolicy = lib.mkDefault "batch";
  nix.daemonIOSchedClass = lib.mkDefault "idle";
  nix.daemonIOSchedPriority = lib.mkDefault 7;
  # https://wiki.nixos.org/wiki/Maintainers:Fastly#Cache_v2_plans
  #nix.binaryCaches = [ "https://aseipp-nix-cache.global.ssl.fastly.net" ];
  #services.swapspace.enable = true;
  services.earlyoom = {
    enable = true;
    enableNotifications = true;
    #    FIXME: unrecognized option '--prefer '^(.firefox-wrappe|java)$''
    #    extraArgs =
    #      let
    #        catPatterns = patterns: builtins.concatStringsSep "|" patterns;
    #        preferPatterns = [
    #          ".firefox-wrapped"
    #          "java" # If it's written in java it's uninmportant enough it's ok to kill it
    #        ];
    #        avoidPatterns = [
    #          "bash"
    #          "zsh"
    #          "sshd"
    #          "systemd"
    #          "systemd-logind"
    #          "systemd-udevd"
    #        ];
    #      in
    #      [
    #        "--prefer '^(${catPatterns preferPatterns})$'"
    #        "--avoid '^(${catPatterns avoidPatterns})$'"
    #      ];
  };

  #  virtualisation.appvm = {
  #    enable = true;
  #    user = config.hostSpec.primaryUsername;
  #  };

  # Bluetooth
  # FIXME: Make this a module? hardware should be enabled by facter...
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
}
