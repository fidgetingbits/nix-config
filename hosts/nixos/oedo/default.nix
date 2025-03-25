# Dell Precision 5570
{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = lib.flatten [
    (map lib.custom.relativeToRoot [
      ##
      # Core
      ##
      "hosts/common/core"
      "hosts/common/core/nixos.nix"

      ##
      # Optional
      ##

      # Host-specific stuff
      "hosts/common/optional/msmtp.nix"
      "hosts/common/optional/plymouth.nix"
      "hosts/common/optional/printing.nix"
      "hosts/common/optional/locale.nix"
      "hosts/common/optional/x11.nix"
      "hosts/common/optional/sound.nix"
      "hosts/common/optional/podman.nix"
      "hosts/common/optional/cli.nix"
      "hosts/common/optional/yubikey.nix"
      "hosts/common/optional/tobii.nix"
      "hosts/common/optional/libvirt.nix"

      "hosts/common/optional/wireshark.nix"

      "hosts/common/optional/systemd-resolved.nix"
      "hosts/common/optional/vpn.nix"

      # Window Manager
      "hosts/common/optional/gnome.nix"

      "hosts/common/optional/binaryninja.nix"
      "hosts/common/optional/cynthion.nix"
      "hosts/common/optional/saleae.nix"

      # Services
      "hosts/common/optional/mounts/oath-cifs.nix"
      "hosts/common/optional/mounts/onus-cifs.nix"
      "hosts/common/optional/mounts/s3fs.nix"
      "hosts/common/optional/services/openssh.nix"
      "hosts/common/optional/services/syncthing.nix"
      "hosts/common/optional/services/gns3.nix"

    ])
    # Impermanence
    (lib.custom.relativeToRoot "hosts/common/disks/btrfs-luks-impermanence-disko.nix")
    {
      _module.args = {
        withSwap = true;
      };
    }
    ./hardware-configuration.nix
    # lanzaboote
    #./secureboot.nix
  ];

  hostSpec = {
    hostName = "oedo";
    isWork = lib.mkForce true;
    voiceCoding = lib.mkForce true;
    useYubikey = lib.mkForce true;
    wifi = lib.mkForce true;
    useNeovimTerminal = lib.mkForce true;
    persistFolder = lib.mkForce "/persist";
    isProduction = lib.mkForce true;
    isAutoStyled = lib.mkForce true;
    isDevelopment = lib.mkForce true;
  };
  system.impermanence.enable = true;

  nixpkgs.config.nvidia.acceptLicense = true;

  services.backup = {
    enable = true;
    borgBackupStartTime = "22:00:00";
  };

  # Bootloader.
  boot.loader.systemd-boot = {
    enable = true;
    # When using plymouth, initrd can expand by a lot each time, so limit how many we keep around
    configurationLimit = lib.mkDefault 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "ntfs" ];
  boot.initrd.systemd.enable = true;

  # We need IPv6 in order to access hetzner cloud
  #networking.networkmanager.enable = true;
  networking.enableIPv6 = true;
  networking.useDHCP = lib.mkDefault true;
  # FIXME(network): Ideally this should be done using the networking.interfaces approach, but doesn't seem to work...
  # In the interfaces change due to me using usb dongles, we should explicitly test if they interface being used is
  # assign to an IP address that we expect to be the one we want their route for
  networking.dhcpcd.runHook =
    let
      network = inputs.nix-secrets.networking;
    in
    ''
      if [ "$reason" = "BOUND" ]; then
        if [ "$new_ip_address" = "${network.subnets.ogre.hosts.oedo.ip}" ]; then
          ${lib.getBin pkgs.iproute2}/bin/ip route add \
            ${network.subnets.lab.cidr} \
            via ${network.subnets.ogre.hosts.ottr.ip} \
            dev $interface \
            2>>/tmp/error
        fi
        # ${lib.getBin pkgs.iproute2}/bin/ip route add \
        #   ${network.subnets.lab.cidr} \
        #   via ${network.subnets.ogre.hosts.ottr.ip} \
        #   dev enp0s20f0u1u4 \
        #   2>>/tmp/error
    '';

  # FIXME(network): This should move to work specific file
  # not working...
  # Setup custom routes for the lab
  #  networking.interfaces =
  #    let
  #      interfaceNames = [
  #        "enp0s13f0u1u1"
  #        "wlp0s20f3"
  #      ];
  #      labRoute = {
  #        address = inputs.nix-secrets.networking.subnets.lab.ip;
  #        prefixLength = inputs.nix-secrets.networking.subnets.lab.prefixLength;
  #        via = inputs.nix-secrets.networking.subnets.ogre.hosts.ottr.ip;
  #      };
  #      interfaceRoutes = lib.attrsets.mergeAttrsList (
  #        lib.map (name: { ${name}.ipv4.routes = [ labRoute ]; }) interfaceNames
  #      );
  #    in
  #    lib.trace lib.trace interfaceRoutes;

  networking.interfaces.enp0s20f0u2u4.ipv4.routes = [
    {
      address = inputs.nix-secrets.networking.subnets.lab.ip;
      prefixLength = inputs.nix-secrets.networking.subnets.lab.prefixLength;
      via = inputs.nix-secrets.networking.subnets.ogre.hosts.ottr.ip;
    }
  ];

  networking.interfaces.wlp0s20f3.ipv4.routes = [
    {
      address = inputs.nix-secrets.networking.subnets.lab.ip;
      prefixLength = inputs.nix-secrets.networking.subnets.lab.prefixLength;
      via = inputs.nix-secrets.networking.subnets.ogre.hosts.ottr.ip;
    }
  ];

  # WARNING: This prevented your internet from working...
  #systemd.network = {
  #  enable = true;
  #  links."10-eth0" = {
  #    linkConfig.Name = "eth0";
  #    matchConfig.MACAddress = config.hostSpec.networking.foo;
  #  };
  #  links."11-wlan0" = {
  #    linkConfig.Name = "wlan0";
  #    matchConfig.MACAddress = config.hostSpec.networking.bar;
  #  };
  #};
  #systemd.network.wait-online.ignoredInterfaces = [ "wlan0" ];

  services.gnome.gnome-keyring.enable = true;

  # Automatically try to unlock gnome-keyring on login
  # gdm is the gnome display manager
  security.pam.services.gdm.enableGnomeKeyring = true;
  # sddm is the simple desktop display manager (used by kde)
  security.pam.services.sddm.enableGnomeKeyring = true;

  voiceCoding.enable = true;

  # ooze checks for all other hosts, so we just check ooze
  services.heartbeat-check = {
    enable = true;
    interval = 10 * 60;
    hosts = [ "ooze" ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  system.stateVersion = "23.05"; # Did you read the comment?
}
