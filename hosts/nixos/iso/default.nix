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
    (lib.custom.scanPaths ./.) # Load all extra host-specific *.nix files
    (map lib.custom.relativeToRoot [
      # FIXME: Switch this to just import hosts/common/core (though have to be careful to purposefully not add platform file..
      "hosts/common/optional/minimal-user.nix"
      "hosts/common/optional/keyd.nix"
      "modules/common/host-spec.nix"
    ])
    (
      let
        # FIXME: Infinite recursion if we use config.hostSpec.username
        path = lib.custom.relativeToRoot "hosts/common/users/aa/default.nix";
      in
      lib.optional (lib.pathExists path) path
    )
  ];

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

  # FIXME: Seems like suspend disable in iso isn't always working
  # home-manager.users.${hostSpec.username}.dconf.settings = {
  #   "org/gnome/settings-daemon/plugins/power" = {
  #     ambient-enabled = false;
  #     idle-dim = true;
  #     power-button-action = "interactive";
  #     sleep-inactive-ac-type = "nothing";
  #     sleep-inactive-ac-timeout = 0;
  #     sleep-inactive-battery-type = "nothing";
  #     sleep-inactive-battery-timeout = 0;
  #   };
  # };

  # root's ssh key are mainly used for remote deployment
  users.extraUsers.root = {
    inherit (config.users.users.${config.hostSpec.username}) hashedPassword;
    openssh.authorizedKeys.keys =
      config.users.users.${config.hostSpec.username}.openssh.authorizedKeys.keys;
  };
}
