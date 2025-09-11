# Core functionality for every nixos host
{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    #inputs.nixvim-flake.nixosModules.nixvim
    inputs.nixcats-flake.nixosModules.default
  ];

  # FIXME: Make this host region dependent
  time.timeZone = "Asia/Taipei";

  # Core packages not available on darwin
  environment.systemPackages = builtins.attrValues {
    inherit (pkgs)
      cntr # derivation debugging
      # editing
      xclip # required for clipboard with vim

      # ricing
      plymouth # bootscreen
      adi1090x-plymouth-themes # https://github.com/adi1090x/plymouth-themes
      ;
  };

  # FIXME: Move this once I get a darwinModules output for nixvim-flake and end up with this option
  neovim.voice-coding = config.hostSpec.voiceCoding;

  # Database for aiding terminal-based programs
  environment.enableAllTerminfo = true;
  # enable firmware with a license allowing redistribution
  hardware.enableRedistributableFirmware = true;

  networking.hosts =
    let
      network = config.hostSpec.networking;
    in
    {
      # FIXME(networking): oxid IP will be different depending on if we are on it's network or not
      "oxid.${config.hostSpec.domain}" = [ network.subnets.oxid.gateway ];
      "oxid-external.${config.hostSpec.domain}" = [
        network.subnets.ogre.hosts.oxid.ip
      ];
    }
    // lib.optionalAttrs config.hostSpec.isWork network.work.hosts;

  environment = {
    localBinInPath = true;

    # From https://github.com/matklad/config/blob/master/hosts/default.nix
    etc."xdg/user-dirs.defaults".text = ''
      DOWNLOAD=downloads
      TEMPLATES=tmp
      PUBLICSHARE=/var/empty
      DOCUMENTS=documents
      MUSIC=media/music
      PICTURES=images
      VIDEOS=media/video
      DESKTOP=.desktop
    '';
  };

  # FIXME: does this work on darwin? should it be in home-manager?
  programs.nix-ld.enable = true;

  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep-since 20d --keep 20";
    };
  };

  # This should be handled by config.security.pam.sshAgentAuth.enable
  security.sudo.extraConfig = ''
    Defaults lecture = never # rollback results in sudo lectures after each reboot, it's somewhat useless anyway
    Defaults pwfeedback # password input feedback - makes typed password visible as asterisks
    Defaults timestamp_timeout=120 # only ask for password every 2h
    # Keep SSH_AUTH_SOCK so that pam_ssh_agent_auth.so can do its magic.
    Defaults env_keep+=SSH_AUTH_SOCK
  '';

  # FIXME: I've run into a case on ooze where logging just stopped... and I had to restart systemd-journald. Should
  # maybe add a service to restart it if it stops and also send an alert. For now I just restart weekly
  services.journald.extraConfig = ''
    SystemMaxUse=4G
    SystemKeepFree=10G
    SystemMaxFileSize=128M
    SystemMaxFiles=500
    MaxFileSec=1month
    MaxRetentionSec=2month
  '';
  systemd.timers."restart-journald" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Unit = "restart-journald.service";
    };
  };

  systemd.services."restart-journald" = {
    script = ''
      ${pkgs.systemd}/bin/systemctl restart systemd-journald
    '';
    serviceConfig.Type = "oneshot";
  };

  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ]; # Apply to all keyboards
      settings = {
        main = {
          # NOTE: This conflicts with zsh sudo plugin in that sometimes too quick
          # ctrl+<key> or similar presses will add a sudo to a command
          capslock = "overload(control, esc)";
          enter = "overload(control, enter)";
          # Careful with this due to typing too fast
          # space = "overload(alt, space)";
          rightalt = "overload(meta, compose)";
          leftcontrol = "layer(layer1)";
          rightcontrol = "layer(layer1)";
          # FIXME: this key only on onyx
          menu = "super";
        };
        layer1 = {
          h = "left";
          j = "down";
          k = "up";
          l = "right";
        };
        shift = {
          leftshift = "capslock";
          rightshift = "capslock";
        };
      };
    };
  };

  # https://wiki.archlinux.org/title/KMSCON
  services.kmscon = {
    # Use kmscon as the virtual console instead of gettys.
    # kmscon is a kms/dri-based userspace virtual terminal implementation.
    # It supports a richer feature set than the standard linux console VT,
    # including full unicode support, and when the video card supports drm should be much faster.
    enable = true;
    fonts = [
      {
        name = "Source Code Pro";
        package = pkgs.source-code-pro;
      }
    ];
    extraOptions = "--term xterm-256color";
    extraConfig = "font-size=12";
    # Whether to use 3D hardware acceleration to render the console.
    hwRender = true;
  };

  # Enable automatic login for the user.
  # FIXME: we will want to tweak the user on multi-user systems
  services.displayManager = lib.optionalAttrs config.hostSpec.useWindowManager {
    autoLogin.enable = true;
    autoLogin.user = config.hostSpec.username;
  };

}
