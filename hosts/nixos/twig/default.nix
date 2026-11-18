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
          "sound.nix"
          "icons.nix"

          "yubikey.nix"
          "systemd-resolved.nix"
          "opensnitch.nix"
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

  boot.initrd.systemd.enable = true;

  # Keyring, required for auth even without gnome
  # FIXME: double check this
  security.pam.services.sddm.enableGnomeKeyring = true;
  ${namespace} = {
    modules.hardware.radeon.enable = true;
    services.backup.enable = false;
    #    networking.granularFirewall.enable = true;
  };

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

  # FIXME: need to add key
  # services.remoteLuksUnlock = {
  #   enable = true;
  #   notify.to = config.hostSpec.email.olanAdmins;
  # };

  # Bluetooth
  services.blueman.enable = true;

  systemd.user.services.xdg-desktop-portal = {
    overrideStrategy = "asDropin";
    unitConfig = {
      Wants = [ "xdg-desktop-portal-gnome.service" ];
      After = [ "xdg-desktop-portal-gnome.service" ];
    };
  };

  networking.hosts =
    let
      # inherit (config.hostSpec) domain;
    in
    {
      # Uncomment when on grove
      # ${subnets.grove.hosts.moth.ip} = [ "moth.${config.hostSpec.domain}" ];
      # Uncomment when on moat
      # ${subnets.moon.hosts.moon.ip} = [ "moon.${config.hostSpec.domain}" ];
    };

  # FIXME: This is a big sketchy, but works for the ossa packages okay (fails on others)
  nixpkgs.config.rocmSupport = config.hostSpec.useRocm;

  services.tailscale.enable = true;
  # FIXME: These are from the wiki, confirm
  networking.firewall = {
    # Always allow traffic from your Tailscale network
    trustedInterfaces = [ config.services.tailscale.interfaceName ];
    # Allow the Tailscale UDP port through the firewall
    allowedUDPPorts = [ config.services.tailscale.port ];
  };
  systemd.services.tailscaled.serviceConfig.Environment = [
    "TS_DEBUG_FIREWALL_MODE=nftables"
  ];
}
