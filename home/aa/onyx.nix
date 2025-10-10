{
  config,
  pkgs,
  lib,
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
          "ssh"
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

          # === Window Managers ===
          # FIXME: This should only be if not wayland
          "desktop/i3"
          "desktop/gnome"
          # FIXME: This should only be if wayland
          "desktop/wayland"
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
          "llm.nix"
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

  home.packages = builtins.attrValues {
    inherit (pkgs)
      cyberpower-pdu
      easylkb
      ntfs3g
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

  services.swww2.enable = true;

  # FIXME: Move this to tridactyl location
  # See https://github.com/DivitMittal/firefox-nixCfg/blob/dc55e3750eac4d6381301901e269106efae621ff/config/tridactyl/config/tridactylrc for more examples (and tridactyl repo)
  xdg.configFile."tridactyl/tridactylrc" = {
    enable = true;
    source = (lib.custom.relativeToRoot "modules/home/firefox/tridactylrc");
    recursive = true;
  };
  programs.firefox.nativeMessagingHosts = [ pkgs.tridactyl-native ];

  # Allows to show talon icon in system tray.
  # NOTE: Important this doesn't run if using wayland, as conflicts with waybar
  services.snixembed.enable = config.hostSpec.voiceCoding;
  services.yubikey-touch-detector.enable = true;
  services.yubikey-touch-detector.notificationSound = true;

  sops = {
    secrets = {
      "tokens/fly" = {
        path = "${config.home.homeDirectory}/.config/fly.io/token";
      };
    };
  };

  #
  # ========== Host-specific Monitor Spec ==========
  #
  # This uses the nix-config/modules/home/monitors.nix module
  # Your nix-config/home/<user>/common/optional/desktops/foo.nix WM config should parse and apply these values to it's monitor settings
  # If on hyprland, use `hyprctl monitors` to get monitor info.
  # https://wiki.hyprland.org/Configuring/Monitors/
  #           -------
  #         | HDMI-A-1 |
  #           -------
  #           -------
  #          | eDP-1 | (disabled by default)
  #           -------
  # FIXME: HDMI-A-1 and HDMI-B-1 are "common" monitors possibly used by other systems, so
  # place them in some common folder
  monitors = [
    {
      name = "HDMI-A-1";
      width = 2560;
      height = 2880;
      refreshRate = 120;
      #transform = 2;
      scale = 1;
    }
    {
      name = "eDP-1";
      width = 3840;
      height = 2160;
      refreshRate = 60;
      #transform = 2;
      scale = 2;
    }
  ];
}
