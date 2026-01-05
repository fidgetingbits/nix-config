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
          "xdg.nix"
          "gpg.nix"
          #common/optional/kitty.nix
          "ghostty.nix"
          #common/optional/wezterm.nix
          "gnome-terminal.nix"
          "media.nix"
          "graphics.nix"
          "ebooks.nix"
          "networking/protonvpn.nix"
          "atuin.nix"
          "remmina.nix"
          "yazi.nix"

          # === Window Managers ===
          # FIXME: This should only be if not wayland
          "desktop/i3"
          "desktop/gnome"
          # FIXME: This should only be if wayland
          "desktop/wayland"

          # These should be linked together somehow
          "desktop/hyprland"
          "desktop/kanshi.nix"
          "desktop/waybar.nix"

          "fcitx5"
          # Maybe more role-specific stuff
          "document.nix" # document editing
          "gui-utilities.nix" # core for any desktop
          "chat.nix"
          "reversing"
          "wine.nix"
        ])
    )
  );

  # FIXME: this should be tied to hostSpec.voiceCoding
  talon = {
    enable = false;
    autostart = false;
    pynvim = true;
    #  gaze-ocr = true;
  };

  llm-tools.enable = true;

  home.packages = lib.attrValues {
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
  };

  home.sessionVariables = {
    # This variable prevents the following from being spammed to the console constantly:
    # "MESA: warning: Support for this platform is experimental with Xe KMD, bug reports may be ignored."
    # See https://docs.mesa3d.org/envvars.html for details
    MESA_LOG_FILE = "/dev/null";
  };

  introdus.services.awww = {
    enable = true;
    wallpaperDir = "${config.home.homeDirectory}/images/wallpaper/catppuccin-mocha";
  };

  # FIXME: Move this to tridactyl location
  # See https://github.com/DivitMittal/firefox-nixCfg/blob/dc55e3750eac4d6381301901e269106efae621ff/config/tridactyl/config/tridactylrc for more examples (and tridactyl repo)
  xdg.configFile."tridactyl/tridactylrc" = {
    enable = true;
    source = (lib.custom.relativeToRoot "modules/home/firefox/tridactylrc");
    recursive = true;
  };
  programs.firefox.nativeMessagingHosts = [ pkgs.tridactyl-native ];

  # Allows to show talon icon in system tray on X11
  services.snixembed.enable = osConfig.hostSpec.voiceCoding;

  services.yubikey-touch-detector = {
    enable = true;
    notificationSound = true;
  };

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

}
