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
    inputs.nixcats-flake.nixosModules.default
  ];

  time.timeZone = lib.mkDefault config.hostSpec.timeZone;

  # Core packages not available on darwin
  environment.systemPackages = lib.attrValues {
    inherit (pkgs)
      cntr # derivation debugging
      # editing
      xclip # required for clipboard with vim (FIXME: this is only if not using wayland, so maybe check)
      ;
  };

  # Database for aiding terminal-based programs
  environment.enableAllTerminfo = true;
  # enable firmware with a license allowing redistribution
  hardware.enableRedistributableFirmware = true;

  # Pin to 6.16 for now, as 6.17.x seems to have issues with systemd-boot
  # possibly related to https://github.com/NixOS/nixpkgs/issues/449939
  # boot.kernelPackages = pkgs.linuxPackages_6_16;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Pin a boot entry if it exists. In order to generate the
  # pinned-boot-entry.conf for a "stable" generation run: 'just pin' and then
  # rebuild. See the pin recipe in justfile for more information
  boot.loader.systemd-boot.extraEntries =
    let
      pinned = lib.custom.relativeToRoot "hosts/nixos/${config.hostSpec.hostName}/pinned-boot-entry.conf";
    in
    lib.optionalAttrs (config.boot.loader.systemd-boot.enable && lib.pathExists pinned) {
      "pinned-stable.conf" = lib.readFile pinned;
    };

  # FIXME(networking): Some IPs will be different depending on if we are on
  # there network or not. This needs per-network dispatcher scripts likely,
  # which might preclude a read-only host file like this generates.
  networking.hosts =
    let
      network = config.hostSpec.networking;
    in
    { }
    // lib.optionalAttrs config.hostSpec.isLocal {
      # Internal
      "${network.subnets.oxid.gateway}" = [ "oxid.${config.hostSpec.domain}" ];

      # VMs
      "${network.subnets.vm-lan.hosts.okra.ip}" = [ "okra.${config.hostSpec.domain}" ];
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
  services.displayManager = lib.optionalAttrs config.hostSpec.useWindowManager {
    autoLogin.enable = true;
    autoLogin.user = config.hostSpec.primaryDesktopUsername;
    defaultSession = config.hostSpec.defaultDesktop;
  };

}
