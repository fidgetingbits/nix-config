# Core functionality for every nixos host
{
  config,
  inputs,
  pkgs,
  lib,
  namespace,
  ...
}:
{
  imports = [
    inputs.introdus.nixosModules.default
  ];

  time.timeZone = lib.mkDefault config.hostSpec.timeZone;

  # Core packages not available on darwin
  environment.systemPackages = lib.attrValues (
    {
      inherit (pkgs)
        cntr # derivation debugging
        ;
    }
    # X11 packages
    // lib.optionalAttrs (config.hostSpec.useWindowManager && config.hostSpec.useX11) {
      inherit (pkgs)
        xclip # required for clipboard with vim on x11
        ;
    }
  );

  # Used by noctalia, but just enabling globally for now
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  # Database for aiding terminal-based programs
  environment.enableAllTerminfo = true;
  # enable firmware with a license allowing redistribution
  hardware.enableRedistributableFirmware = true;

  boot.kernelPackages =
    if config.hostSpec.isServer then
      pkgs.linuxPackages_6_12 # LTS
    else
      pkgs.linuxPackages_latest;

  boot.loader.efi.canTouchEfiVariables = true;

  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = lib.mkDefault 8;
    # Pin a stable boot entry. In order to generate the pinned-boot-entry.conf
    # for a "stable" generation run 'just pin'.
    # See the pin recipe in justfile for more information
    extraEntries =
      let
        pinned = lib.custom.relativeToRoot "hosts/nixos/${config.hostSpec.hostName}/pinned-boot-entry.conf";
      in
      lib.optionalAttrs (config.boot.loader.systemd-boot.enable && lib.pathExists pinned) {
        "pinned-stable.conf" = lib.readFile pinned;
      };
  };

  networking.hosts =
    let
      inherit (config) hostSpec;
      network = hostSpec.networking;
      domain = hostSpec.domain;
    in
    {
      # FIXME: This should only be local or wireguard peered
      "photos.${domain}" = [
        "immich.ooze.${domain}"
      ];
    }
    // lib.optionalAttrs config.hostSpec.isLocal {
      # Internal
      "${network.subnets.oxid.gateway}" = [ "oxid.${domain}" ];
    }
    // lib.optionalAttrs (hostSpec.isLocal && hostSpec.isDevelopment) {
      "git.${domain}" = [
        "git.ooze.${domain}"
      ];
      # VMs
      "${network.subnets.vm-lan.hosts.okra.ip}" = [ "okra.${config.hostSpec.domain}" ];
    }
    // lib.optionalAttrs config.hostSpec.isWork network.work.hosts;

  # don't wait for dhcpd on boot
  networking.dhcpcd.wait = "background";
  # Stop blocking on network interfaces not needed for boot
  systemd.network.wait-online.enable = false;
  systemd.services.NetworkManager-wait-online.enable = false;
  networking.nftables.enable = true;

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

  services.gnome.gnome-keyring.enable = config.hostSpec.useWindowManager;

  "${namespace}" = {
    attic-client.enable = config.hostSpec.useAtticCache;
  };

  # WARNING:using broker regular breaks switching due to unit not reloading, often
  # requiring multiple rebuilds.
  services.dbus.implementation = "broker";

  # backup mirror assumes users is a shared gid across hosts, so hardcode it in case nixos ever changes the default
  users.groups.users.gid = 100;

  # FIXME: Move to hardening
  # copy fail / dirty frag mitigations
  boot.blacklistedKernelModules = [
    "af_alg"
    "algif_aead"
    "algif_skcipher"
    "algif_hash"
    "algif_rng"

    "esp4"
    "esp6"
    "rxrpc"
  ];
  boot.extraModprobeConfig = ''
    install af_alg         ${pkgs.coreutils}/bin/false
    install algif_aead     ${pkgs.coreutils}/bin/false
    install algif_skcipher ${pkgs.coreutils}/bin/false
    install algif_hash     ${pkgs.coreutils}/bin/false
    install algif_rng      ${pkgs.coreutils}/bin/false
    install authenc        ${pkgs.coreutils}/bin/false
    install authencesn     ${pkgs.coreutils}/bin/false

    install esp4           ${pkgs.coreutils}/bin/false
    install esp6           ${pkgs.coreutils}/bin/false
    install rxrpc          ${pkgs.coreutils}/bin/false
  '';

  # FIXME: Move to styling
  # Some ricing for all systems. This is in nixos vs hm because nft needs sudo, which
  # so sudo grc nft won't pick up the ~/.grc/ conf file, and | grcat <style> is tedious
  environment.etc = {
    # FIXME: Not sure the sudo prefix regex makes sense, since we likely sudo grc nft?
    "grc.conf".text = ''
      # Match any sudo or raw invocation of nft list
      (^nft\s+.*list.*|^sudo\s+nft\s+.*list.*)
      /etc/grc/conf.nftables
    '';

    # FIXME: This is auto-generated atm. Needs work, but is better than nothing
    "grc/conf.nftables".text = ''
      # 1. Comments (Do this first so keywords inside comments don't get colored)
      regexp=#.*$
      colours=white
      -
      # 2. Double-quoted strings (e.g., log prefixes or interface names)
      regexp="[^"]*"
      colours=yellow
      -
      # 3. Table, Chain, and Set declarations
      # Matches: 'table inet nixos-fw' or 'set temp-ports'
      regexp=\b(table|chain|ruleset|set)\s+([\w-]+)\s+([\w-]+)?
      colours=bold yellow, green, cyan
      -
      # 4. Hooks, Priorities, Policies, and Device types
      regexp=\b(type|hook|priority|policy|device)\s+([\w+-]+)
      colours=blue, bold blue
      -
      # 5. Core Actions / Verdicts / Flow Control
      regexp=\b(accept|drop|reject|masquerade|counter|log|jump|goto|return|vmap)\b
      colours=bold red
      -
      # 6. Protocol Layers & Meta expressions (expanded)
      regexp=\b(ip|ip6|inet|arp|tcp|udp|icmp|icmpv6|ct|meta|fib|ether)\b
      colours=cyan
      -
      # 7. Traffic Selectors (saddr, daddr, sport, dport)
      regexp=\b([sd]addr|[sd]port)\b
      colours=bold magenta
      -
      # 8. Set references (e.g., @temp-ports)
      regexp=@[\w-]+
      colours=bold cyan
      -
      # 9. Inline criteria & states (flags, state names, interface matching)
      regexp=\b(iifname|oifname|state|flags|interval|established|related|new|invalid|untracked|exists|check)\b
      colours=magenta
      -
      # 10. IPv4 / IPv6 addresses and CIDR blocks inside rules
      regexp=\b([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?|[a-fA-F0-9:]+::?(/[0-9]{1,3})?)\b
      colours=bright_white
      -
      # 11. Highlight handles at the end of lines
      regexp=handle\s+\d+
      colours=green
    '';
  };

  system.stateVersion = "23.05";
}
