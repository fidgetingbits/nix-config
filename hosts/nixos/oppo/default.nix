{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:
{
  imports = lib.flatten [
    ./hardware-configuration.nix
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-amd

    (map lib.custom.relativeToRoot [
      "hosts/common/core"
      "hosts/common/core/nixos.nix"

      # Host-specific stuff
      "hosts/common/optional/msmtp.nix"
      # WARNING: Blocks on boot on both gpus atm (Granite Ridge and 9070XT)
      #"hosts/common/optional/plymouth.nix"
      "hosts/common/optional/locale.nix"
      #"hosts/common/optional/wayland.nix"
      "hosts/common/optional/sound.nix"

      # Desktop environment and login manager
      "hosts/common/optional/x11.nix"
      # "hosts/common/optional/gdm.nix"
      "hosts/common/optional/sddm.nix"

      #"hosts/common/optional/greetd.nix"
      #"hosts/common/optional/hyprland.nix"
      "hosts/common/optional/gnome.nix"

      #"hosts/common/optional/podman.nix"
      "hosts/common/optional/libvirt.nix"
      "hosts/common/optional/cli.nix"
      "hosts/common/optional/yubikey.nix"
      "hosts/common/optional/services/openssh.nix"

      # Network management
      "hosts/common/optional/systemd-resolved.nix"

      # Remote network mounts and syncing
      #"hosts/common/optional/mounts/oath-cifs.nix"
      #"hosts/common/optional/services/syncthing.nix"

      # Gaming
      "hosts/common/optional/gaming.nix"

      "hosts/common/optional/remote-builder.nix"

      "hosts/common/optional/fonts.nix"

      "hosts/common/optional/lgtv.nix"

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
    hdr = lib.mkForce true;
    scaling = lib.mkForce "2";
    isProduction = lib.mkForce true;
    useAtticCache = lib.mkForce false;
    isDevelopment = lib.mkForce true;
    persistFolder = lib.mkForce "/persist";
    useWayland = lib.mkForce true;
  };
  system.impermanence.enable = true;

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    # Bootloader.
    loader.systemd-boot = {
      enable = true;
      # When using plymouth, initrd can expand by a lot each time, so limit how many we keep around
      configurationLimit = lib.mkDefault 10;
    };
    loader.efi.canTouchEfiVariables = true;

    initrd.kernelModules = [ "amdgpu" ];
    kernelParams = [
      "amdgpu.ppfeaturemask=0xfffd3fff" # https://kernel.org/doc/html/latest/gpu/amdgpu/module-parameters.html#ppfeaturemask-hexint
      "amdgpu.dcdebugmask=0x400" # Allegedly might help with some crashes
      "split_lock_detect=off" # Alleged gaming perf increase
    ];
    # Fix for XBox controller disconnects
    extraModprobeConfig = ''options bluetooth disable_ertm=1 '';
  };

  # xbox series s/x controller support
  hardware = {
    xpadneo.enable = true;
    steam-hardware.enable = true;
  };

  # Just set the console font, don't mess with the font settings
  #console.font = lib.mkDefault "${pkgs.terminus_font}/share/consolefonts/ter-v32n.psf.gz";
  console.earlySetup = lib.mkDefault true;

  networking.networkmanager.enable = true;
  networking.useDHCP = lib.mkDefault true;

  networking.networkmanager.ensureProfiles.profiles = {
    usb-eth = {
      connection = {
        id = "usb-eth";
        type = "ethernet";
        interface-name = "usb-eth";
      };
      ethernet = { };
      ipv4 = {
        method = "manual";
        addresses = config.hostSpec.networking.subnets.tv.hosts.oppo.ip + "/24";
      };
      ipv6 = {
        method = "disabled";
      };
    };
  };

  # Keyring, required for auth even without gnome
  security.pam.services.sddm.enableGnomeKeyring = true;

  environment.systemPackages = builtins.attrValues {
    inherit (pkgs)
      # gnupg - see yubikey.nix
      paperkey # printed gpg key backup utilitie
      pinentry-curses # for gpg-agent
      pinentry-gtk2 # for gpg-agent
      liquidctl # control nxzt kraken rgb, not in home-manager because of udev rules
      ;
  };
  services.fwupd.enable = true;
  services.backup = {
    enable = true;
    borgBackupStartTime = "11:00:00";
    borgExcludes = [
      "${config.hostSpec.home}/movies"
      "${config.hostSpec.home}/.local/share/Steam"
    ];
  };

  # openrgb
  # FIXME: Move all this
  services.udev.packages = [ pkgs.openrgb-with-all-plugins ];
  boot.kernelModules = [ "i2c-dev" ];
  hardware.i2c.enable = true;
  services.hardware.openrgb = {
    enable = true;
    package = pkgs.openrgb-with-all-plugins;
    motherboard = "amd";
    server = {
      port = 6742;
    };
  };
  systemd.services.openrgb-pre-suspend = {
    description = "Set OpenRGB to off before suspend";
    wantedBy = [
      "halt.target"
      "sleep.target"
      "suspend.target"
    ];
    before = [
      "sleep.target"
      "suspend.target"
    ];
    partOf = [ "openrgb.service" ];
    requires = [ "openrgb.service" ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "20s";
      ExecStart = "${pkgs.openrgb}/bin/openrgb --mode off";
    };
  };
  systemd.services.openrgb-post-resume = {
    description = "Reload OpenRGB profile after resume";
    wantedBy = [
      "post-resume.target"
      "suspend.target"
    ];
    after = [
      "openrgb.service"
      "suspend.target"
    ];
    requires = [ "openrgb.service" ];
    partOf = [ "openrgb.service" ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "10s";
      ExecStart = "${pkgs.openrgb}/bin/openrgb -m static --color FFFFFF";
      # ExecStart = "${pkgs.openrgb}/bin/openrgb --profile ${./oppo.orp}";
    };
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="net", ACTION=="add", ATTRS{idVendor}=="0b95", ATTRS{idProduct}=="7720", NAME="usb-eth"
    ${builtins.readFile "${pkgs.liquidctl}/lib/udev/rules.d/71-liquidctl.rules"}
  '';

  #networking.granularFirewall.enable = true;

  powerManagement = {
    enable = true;
    cpuFreqGovernor = "ondemand";
    # Prevent USB devices from waking up the system
    powerUpCommands = ''
      echo XHC0 > /proc/acpi/wakeup
      echo XHC1 > /proc/acpi/wakeup
      echo XHC2 > /proc/acpi/wakeup
    '';
  };

  system.stateVersion = "23.05";
}
