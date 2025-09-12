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
          "ssh.nix"
          "audio-tools.nix"
          "vscode"
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
          "i3"
          "gnome"
          # FIXME: This should only be if wayland
          "hyprland"
          "waybar.nix"

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

  # Allows to show talon icon in system tray
  services.snixembed.enable = true;
  services.yubikey-touch-detector.enable = true;
  services.yubikey-touch-detector.notificationSound = true;

  sops = {
    secrets = {
      "tokens/fly" = {
        path = "${config.home.homeDirectory}/.config/fly.io/token";
      };
    };
  };
}
