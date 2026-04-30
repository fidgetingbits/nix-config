{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = lib.flatten [
    #"${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-graphical-gnome.nix"
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"

    # FIXME: These should just be added everywhere now?
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
    inputs.introdus.nixosModules.default

    (lib.custom.scanPaths ./.) # Load all extra host-specific *.nix files
    (map lib.custom.relativeToRoot [
      # FIXME: Switch this to just import hosts/common/core (though have to be careful to purposefully not add platform file..
      "hosts/common/optional/minimal-user.nix"
      "hosts/common/optional/keyd.nix"
      "modules/hosts/common/host-spec.nix"
      "modules/hosts/nixos/auto/warnings.nix"
      "hosts/common/users"
    ])
  ];

  environment.etc = {
    isoBuildTime = {
      #
      text = lib.readFile "${pkgs.runCommand "timestamp" {
        # builtins.currentTime requires --impure
        env.when = builtins.currentTime;
      } "echo -n `date -d @$when  +%Y-%m-%d_%H-%M-%S` > $out"}";
    };
  };

  # Add the build time to the prompt so it's easier to know the ISO age
  programs.bash.promptInit = ''
    export PS1="\\[\\033[01;32m\\]\\u@\\h-$(cat /etc/isoBuildTime)\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\]\\$ "
  '';

  # The default compression-level (6) takes way too long on onyx (>30m). 3 takes <2m
  isoImage.squashfsCompression = "zstd -Xcompression-level 3";

  nixpkgs = {
    hostPlatform = lib.mkDefault "x86_64-linux";
    config.allowUnfree = true;
    overlays = [
      (final: prev: {
        unstable = import inputs.nixpkgs-unstable {
          system = final.stdenv.hostPlatform.system;
          config.allowUnfree = true;
        };
      })
      inputs.introdus.overlays.default
    ];
  };

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
      "pipe-operators"
    ];
  };

  services = {
    qemuGuest.enable = true;
    openssh = {
      ports = [ config.hostSpec.networking.ports.tcp.ssh ];
      settings.PermitRootLogin = lib.mkForce "yes";
    };
  };

  boot = {
    supportedFilesystems = lib.mkForce [
      "btrfs"
      "vfat"
    ];
  };

  networking = {
    hostName = "iso";
  };

  # gnome power settings do not turn off screen
  systemd = {
    services.sshd.wantedBy = pkgs.lib.mkForce [ "multi-user.target" ];
    targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };
  };

  # root's ssh key are mainly used for remote deployment
  users.users.root = {
    # Needed for https://github.com/nix-community/nixos-anywhere/issues/280#issuecomment-4319910463
    # To avoid zsh:1: no matches found: local?root=/mnt
    # Overrides the default zsh set in users/default.nix
    shell = lib.mkForce pkgs.bashInteractive;
    # inherit (config.users.users.${config.hostSpec.username}) hashedPassword;
  };
  users.extraUsers.root = {
    hashedPassword = lib.mkForce config.users.users.${config.hostSpec.username}.hashedPassword;
    openssh.authorizedKeys.keys =
      lib.mkForce
        config.users.users.${config.hostSpec.username}.openssh.authorizedKeys.keys;
  };
}
