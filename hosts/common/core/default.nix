# This file (and the global directory) holds config that I use on all hosts
# except nixos-installer. IMPORTANT: This is used by NixOS and nix-darwin so
# options must exist in both!
{
  inputs,
  outputs,
  config,
  lib,
  pkgs,
  isDarwin,
  secrets,
  ...
}:
let
  platform = if isDarwin then "darwin" else "nixos";
  platformModules = "${platform}Modules";
in
{
  imports = lib.flatten [
    inputs.home-manager.${platformModules}.home-manager
    inputs.sops-nix.${platformModules}.sops
    inputs.disko.${platformModules}.disko
    inputs.nix-index-database.${platformModules}.nix-index
    { programs.nix-index-database.comma.enable = true; }

    (map lib.custom.relativeToRoot [
      "modules/hosts/common"
      "modules/hosts/${platform}"

      "hosts/common/core/sops.nix" # Core because it's used for backups, mail
      "hosts/common/core/cli.nix"
      "hosts/common/core/${platform}.nix"

      "hosts/common/users"
    ])
  ];

  nixpkgs = {
    config = {
      allowUnfree = true;
      allowBroken = true;
    };
    overlays = [
      outputs.overlays.default # our own flake overlays
      inputs.talon-nix.overlays.default
      inputs.introdus.overlays.default
    ];
  };

  networking.hostName = config.hostSpec.hostName;
  # Disabled to simplify ip addr output / firewall rules, since not using anywhere anyway
  networking.enableIPv6 = false;

  # System-wide packages, in case we log in as root
  # FIXME: This is somewhat duplicated with home
  environment.systemPackages = lib.attrValues {
    inherit (pkgs)
      openssh
      eza # ls replacement
      zoxide # cd replacement
      fd # tree-style ls
      procs # ps replacement
      duf # df replacement
      ripgrep # grep replacement
      dust # du replacement
      p7zip # archive
      pstree # tree-style ps
      lsof # list open files
      eva # cli calculator
      hexyl # hexdump replacement
      grc # colorize output
      fastfetch
      jq # json
      gnupg
      yq-go # yaml
      dig

      findutils # find
      file # file type analysis

      # network utilities
      iputils # ping, traceroute, etc
      ;
  };

  # FIXME: Need to see if this is better than gnome, etc
  programs.ssh.askPassword = pkgs.lib.mkForce "${pkgs.kdePackages.ksshaskpass.out}/bin/ksshaskpass";

  # If there is a conflict file that is backed up, use this extension
  home-manager.backupFileExtension = "bk";

  # FIXME: This isn't always accurate info if system is remotely managed, so need to
  # rework it. Ideally want to check something like isRemotelyManaged, but
  # will have to be like isDarwin outside of host-spec
  hostSpec = {
    primaryUsername = lib.mkDefault "aa";
    username = lib.mkDefault "aa"; # FIXME: deprecate
    # users = [ "aa" ];
    handle = "fidgetingbits";
    inherit (secrets)
      domain
      email
      userFullName
      networking
      work
      ;
  };

  nix.optimise = {
    # Automatic nix optimization is incompatible with running microvms. This is because the closure used for
    # an already running microvm may be "optimized" by shuffling links, and this can result in the /nix/store
    # mount being disrupted. You end up with an unusable system due to stale file handle errors everywhere
    # This is only true (I think) if you map the host /nix/store into the microvm, but atm that's what I do.
    automatic = (lib.length (lib.attrNames config.microvm.vms) == 0);
    dates = [ "03:45" ]; # Periodically optimize the store
  };

  security.pki.certificates = lib.flatten (
    lib.optional config.hostSpec.isWork secrets.work.certificates
  );

  # Some quirk of impermanence/btrfs wiping that causes /root base to be recreated with 755
  systemd.tmpfiles.rules = [
    "d /root 0700 root root - -"
  ];

  environment.etc."gitconfig".text = ''
    [url "ssh://git@git.${config.hostSpec.domain}/"]
      insteadOf = ssh://olan-forge/
  '';

  # This shuts up a bunch of warning spam in journal
  # https://github.com/NixOS/nixpkgs/issues/303078
  services.dbus = {
    brokerPackage = pkgs.dbus-broker.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ./dbus-broker-logging.patch
      ];
    });
  };

  # This is a catch all. Some roaming hosts when on the VPN might resolve their
  # own domain to the wrong IP, so just force it to localhost.
  networking.hosts =
    let
      inherit (config.hostSpec) domain hostName;
    in
    {
      "127.0.0.1" = [ "${hostName}.${domain}" ];
    };
}
