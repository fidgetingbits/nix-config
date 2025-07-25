{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
rec {
  imports = lib.flatten [
    #"${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-graphical-gnome.nix"
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
    inputs.home-manager.nixosModules.home-manager
    (map lib.custom.relativeToRoot [
      # FIXME: Switch this to just import hosts/common/core (though have to be careful to purposefully not add platform file..
      "hosts/common/optional/minimal-user.nix"
      "modules/common/host-spec.nix"
    ])
    (
      let
        path = lib.custom.relativeToRoot "hosts/common/users/${hostSpec.username}/default.nix";
      in
      lib.optional (lib.pathExists path) path
    )
  ];

  hostSpec = {
    username = "aa";
    hostName = "iso";
    isProduction = lib.mkForce false;
    networking = inputs.nix-secrets.networking; # Needed because we don't use host/common/core for iso
  };

  environment.etc = {
    isoBuildTime = {
      #
      text = lib.readFile (
        "${pkgs.runCommand "timestamp" {
          # builtins.currentTime requires --impure
          env.when = builtins.currentTime;
        } "echo -n `date -d @$when  +%Y-%m-%d_%H-%M-%S` > $out"}"
      );
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
  };

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    extraOptions = "experimental-features = nix-command flakes";
  };

  services = {
    qemuGuest.enable = true;
    openssh = {
      ports = [ config.hostSpec.networking.ports.tcp.ssh ];
      settings.PermitRootLogin = lib.mkForce "yes";
    };
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
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
  users.extraUsers.root = {
    inherit (config.users.users.${config.hostSpec.username}) hashedPassword;
    openssh.authorizedKeys.keys =
      config.users.users.${config.hostSpec.username}.openssh.authorizedKeys.keys;
  };
}
