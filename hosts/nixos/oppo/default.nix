{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:
{
  imports = lib.flatten [
    # Common
    inputs.nixos-facter-modules.nixosModules.facter
    { config.facter.reportPath = ./facter.json; }
    (lib.custom.scanPaths ./.) # Load all extra host-specific *.nix files

    (map lib.custom.relativeToRoot (
      [
        "hosts/common/core"
        "hosts/common/core/nixos.nix"
      ]
      ++ (map (f: "hosts/common/optional/${f}") [

        # Host-specific stuff
        "keyd.nix"
        "mail-delivery.nix"
        # WARNING: Blocks on boot on both gpus atm (Granite Ridge and 9070XT)
        #"plymouth.nix"
        "locale.nix"
        "sound.nix"

        # Desktop environment and login manager
        "x11.nix"
        "sddm.nix"

        #"hyprland.nix"
        "gnome.nix"

        "libvirt.nix"
        "cli.nix"
        "yubikey.nix"

        # Network management
        "systemd-resolved.nix"

        # Gaming
        "gaming.nix"

        "remote-builder.nix"

        "fonts.nix"

        "nzxt.nix"
      ])
    ))
  ];

  services.lgtv-control =
    let
      ogle = config.hostSpec.networking.subnets.tv.hosts.ogle;
    in
    {
      enable = true;
      ip = ogle.ip;
      mac = lib.elemAt ogle.mac 0;
    };
  services.blueman.enable = true;

  system.impermanence = {
    enable = true;
    autoPersistHomes = true;
  };
  boot = {
    # Cooling / RGB
    kernelModules = [
      "i2c-dev"
      "i2c-piix4"
      "amdgpu-i2c"
    ];

    initrd.kernelModules = [ "amdgpu" ];
    kernelParams = [
      "amdgpu.ppfeaturemask=0xfffd3fff" # https://kernel.org/doc/html/latest/gpu/amdgpu/module-parameters.html#ppfeaturemask-hexint
      "amdgpu.dcdebugmask=0x400" # Allegedly might help with some crashes
      "split_lock_detect=off" # Alleged gaming perf increase
    ];
    # Fix for XBox controller disconnects
    extraModprobeConfig = "options bluetooth disable_ertm=1 ";
  };

  hardware = {
    # xbox series s/x controller support
    xpadneo.enable = true;
    steam-hardware.enable = true;

    # Prevent crashes in steam on the Radeon 9070 XT
    graphics.package = pkgs.unstable.mesa;
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

  environment.systemPackages = lib.attrValues {
    inherit (pkgs)
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

  services.remoteLuksUnlock = {
    enable = true;
    notify.to = config.hostSpec.email.olanAdmins;
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="net", ACTION=="add", ATTRS{idVendor}=="0b95", ATTRS{idProduct}=="7720", NAME="usb-eth"
    ${lib.readFile "${pkgs.liquidctl}/lib/udev/rules.d/71-liquidctl.rules"}
  '';

  tunnels.cakes.enable = true;
  services.logind = {
    settings.Login = {
      HandlePowerKey = lib.mkForce "suspend";
      HandlePowerKeyLongPress = lib.mkForce "poweroff";
    };
  };

  #networking.granularFirewall.enable = true;

  powerManagement = {
    enable = true;
    cpuFreqGovernor = "ondemand";
    # Power up and resume
    powerUpCommands = ''
      # Prevent USB devices from waking up the system
      if grep XHC0 /proc/acpi/wakeup | grep enabled; then
        echo "Disabling USB wakeup devices"
        echo XHC0 > /proc/acpi/wakeup
        echo XHC1 > /proc/acpi/wakeup
        echo XHC2 > /proc/acpi/wakeup
      fi
    '';
  };

  # Enable WoL port
  networking.firewall = {
    allowedUDPPorts = [ 9 ];
  };
  # Should already be on as per ethtool, but just in case
  networking.interfaces.ens3 = {
    wakeOnLan.enable = true;
  };

  modules.hardware.radeon.enable = true;
}
