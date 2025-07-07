# Dell Precision 5570
{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = lib.flatten [
    (
      map lib.custom.relativeToRoot [
        ##
        # Core
        ##
        "hosts/common/core"
        "hosts/common/core/nixos.nix"
      ]
      ++
        # Optional common modules
        (map (f: "hosts/common/optional/${f}") [
          ##
          # Optional
          ##

          # Host-specific stuff
          "msmtp.nix"
          "plymouth.nix"
          "printing.nix"
          "locale.nix"
          "x11.nix"
          "sound.nix"
          "podman.nix"
          "cli.nix"
          "yubikey.nix"
          "tobii.nix"
          "libvirt.nix"

          "wireshark.nix"

          "systemd-resolved.nix"
          "vpn.nix"

          # Window Manager
          "gnome.nix"

          "binaryninja.nix"
          "cynthion.nix"
          "saleae.nix"

          # Services
          "mounts/oath-cifs.nix"
          "mounts/onus-cifs.nix"
          "mounts/s3fs.nix"
          "services/openssh.nix"
          "services/syncthing.nix"
          "services/gns3.nix"

        ])
    )
    # Impermanence
    (lib.custom.relativeToRoot "hosts/common/disks/btrfs-luks-impermanence-disko.nix")
    {
      _module.args = {
        disk = "/dev/nvme0n1";
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
  networking.dhcpcd.wait = "background";
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
  #systemd.services.NetworkManager-wait-online.enable = false;
  #systemd.services.systemd-networkd-wait-online.enable = false;
  systemd.network.wait-online.enable = false;

  services.gnome.gnome-keyring.enable = true;

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
