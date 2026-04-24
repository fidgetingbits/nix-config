{
  config,
  pkgs,
  lib,
  osConfig,
  ...
}:
{
  imports = (
    map lib.custom.relativeToRoot (
      # FIXME: remove after fixing user/home values in HM
      [
        "home/common/core"
        "home/common/core/nixos.nix"
      ]
      ++
        # Optional common modules
        (map (f: "home/common/optional/${f}") [
          "audio-tools.nix"
          #"vscode"
          "development"
          "aws.nix"
          "helper-scripts"
          "sops.nix"
          "gpg.nix"
          "ghostty.nix"
          "gnome-terminal.nix"
          "media.nix"
          "graphics.nix"
          "ebooks.nix"
          "networking/protonvpn.nix"
          "atuin.nix"
          "remmina.nix"
          "yazi.nix"

          # === Window Managers ===
          "desktop/"

          "fcitx5"
          # Maybe more role-specific stuff
          "document.nix" # document editing
          "gui-utilities.nix" # core for any desktop
          "chat.nix"
          "reversing"
          # "wine.nix"
        ])
    )
  );

  llm-tools.enable = true;

  home.packages =
    lib.attrValues {
      inherit (pkgs)
        ntfs3g
        ;
      inherit (pkgs.introdus)
        easylkb
        cyberpower-pdu
        ;
      inherit (pkgs.unstable)
        proton-authenticator
        ;
    }
    ++ [
      (pkgs.long-rsync.overrideAttrs (_: {
        recipients = osConfig.hostSpec.email.olanAdmins;
        deliverer = osConfig.hostSpec.email.notifier;
        sshPort = osConfig.hostSpec.networking.ports.tcp.ssh;
      }))
    ];

  home.sessionVariables = {
    # This variable prevents the following from being spammed to the console constantly:
    # "MESA: warning: Support for this platform is experimental with Xe KMD, bug reports may be ignored."
    # See https://docs.mesa3d.org/envvars.html for details
    MESA_LOG_FILE = "/dev/null";
  };

  introdus.services.awww = {
    enable = true;
    interval = lib.custom.time.days 1;
    wallpaperDir = "${config.home.homeDirectory}/images/wallpaper/catppuccin-mocha";
  };

  # FIXME: Move this to tridactyl location
  # See https://github.com/DivitMittal/firefox-nixCfg/blob/dc55e3750eac4d6381301901e269106efae621ff/config/tridactyl/config/tridactylrc for more examples (and tridactyl repo)
  xdg.configFile."tridactyl/tridactylrc" = {
    enable = true;
    source = (lib.custom.relativeToRoot "modules/home/auto/firefox/tridactylrc");
    recursive = true;
  };
  programs.firefox.nativeMessagingHosts = [ pkgs.tridactyl-native ];

  # Allows to show talon icon in system tray on X11
  services.snixembed.enable = osConfig.hostSpec.voiceCoding;

  # FIXME: Make this part of a module
  services.copyq.enable = true;

  system.ssh-motd.enable = true;

  sops = {
    secrets = {
      "tokens/fly" = {
        path = "${config.home.homeDirectory}/.config/fly.io/token";
      };
    };
  };

  stylix = {
    cursor = lib.mkForce {
      name = lib.mkForce "catppuccin-mocha-light-cursors";
      package = lib.mkForce pkgs.catppuccin-cursors.mochaLight;
      size = lib.mkForce 40;
    };
    # override = {
    #   scheme = "miasma";
    #   author = "xero"; # https://github.com/xero/miasma.nvim/blob/main/extras/miasma.Xresources
    #   base00 = "#222222";
    #   base01 = "#685742";
    #   base02 = "#5f875f";
    #   base03 = "#b36d43";
    #   base04 = "#78824b";
    #   base05 = "#bb7744";
    #   base06 = "#c9a554";
    #   base07 = "#d7c483";
    #   base08 = "#666666";
    #   base09 = "#685742";
    #   base0A = "#5f875f";
    #   base0B = "#b36d43";
    #   base0C = "#78824b";
    #   base0D = "#bb7744";
    #   base0E = "#c9a554";
    #   base0F = "#d7c483";
    # };
    targets.neovide.enable = true;
  };

}
