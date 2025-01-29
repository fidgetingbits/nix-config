# Core functionality for every nixos host
{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
{
  imports = [ inputs.nixvim-flake.nixosModules.nixvim ];

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

  # This is because we use nix-index-database, see https://github.com/nix-community/home-manager/issues/1995
  programs.command-not-found.enable = false;

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

  # Mostly taken from ryan4yin
  fonts = {
    # WARNING: Disabling the below will mess up fonts on sites like
    # https://without.boats/blog/pinned-places/ with huge gaps after the ' character
    enableDefaultPackages = true;
    fontDir.enable = true;
    packages =
      (builtins.attrValues {
        inherit (pkgs)
          # icon fonts
          material-design-icons
          font-awesome

          # Noto 系列字体是 Google 主导的，名字的含义是「没有豆腐」（no tofu），因为缺字时显示的方框或者方框被叫作 tofu
          # Noto 系列字族名只支持英文，命名规则是 Noto + Sans 或 Serif + 文字名称。
          # 其中汉字部分叫 Noto Sans/Serif CJK SC/TC/HK/JP/KR，最后一个词是地区变种。
          # noto-fonts # 大部分文字的常见样式，不包含汉字
          # noto-fonts-cjk # 汉字部分
          noto-fonts-emoji # 彩色的表情符号字体
          # noto-fonts-extra # 提供额外的字重和宽度变种

          # 思源系列字体是 Adobe 主导的。其中汉字部分被称为「思源黑体」和「思源宋体」，是由 Adobe + Google 共同开发的
          source-sans # 无衬线字体，不含汉字。字族名叫 Source Sans 3 和 Source Sans Pro，以及带字重的变体，加上 Source Sans 3 VF
          source-serif # 衬线字体，不含汉字。字族名叫 Source Code Pro，以及带字重的变体
          source-han-sans # 思源黑体
          source-han-serif # 思源宋体

          meslo-lgs-nf
          julia-mono
          dejavu_fonts
          ;
        inherit (pkgs.unstable.nerd-fonts) fira-code iosevka jetbrains-mono;
      })
      ++ [ (pkgs.nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; }) ];

    # the reason there's Noto Color Emoji everywhere is to override DejaVu's
    # B&W emojis that would sometimes show instead of some Color emojis
    fontconfig.defaultFonts = {
      serif = [
        "Source Han Serif SC"
        "Source Han Serif TC"
        "Noto Color Emoji"
        "Iosevka Nerd Font Mono"
        "MesloLGS NF"
        "Nerd Fonts Symbols Only"
        "FiraCode Nerd Font Mono"

      ];
      sansSerif = [
        "Source Han Sans SC"
        "Source Han Sans TC"
        "Noto Color Emoji"
        "Iosevka Nerd Font Mono"
        "MesloLGS NF"
        "Nerd Fonts Symbols Only"
        "FiraCode Nerd Font Mono"
      ];
      monospace = [
        "JetBrainsMono Nerd Font"
        "Noto Color Emoji"
        "Iosevka Nerd Font Mono"
        "MesloLGS NF"
        "Nerd Fonts Symbols Only"
        "FiraCode Nerd Font Mono"
      ];
      emoji = [
        "Noto Color Emoji"
        "Nerd Fonts Symbols Only"
      ];
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
}
