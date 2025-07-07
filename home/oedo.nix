{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = (
    map lib.custom.relativeToRoot (
      [
        "home/common/core"
        "home/common/core/nixos.nix"
      ]
      ++
        # Optional common modules
        (map (f: "home/common/optional/${f}") [

          "ssh.nix"
          "audio-tools.nix"
          "vscode.nix"
          "xdg.nix"
          "helper-scripts"
          "development"
          "aws.nix"
          "gpg.nix"
          "sops.nix"
          "media.nix"
          "gnome-terminal.nix"

          "wezterm.nix"
          "kitty.nix"
          "graphics.nix"

          "atuin.nix"

          "remmina.nix"

          "chat.nix"
          "work.nix"
          "gnome"

          "reversing"

          "wine.nix"

          # "i3"
        ])
    )
  );

  # modules.desktop.i3.enable = true;
  services.yubikey-touch-detector.enable = true;
  services.yubikey-touch-detector.notificationSound = true;

  settings.work.enable = true;

  home.packages = builtins.attrValues {
    inherit (pkgs)
      cyberpower-pdu
      easylkb
      slideshare-downloader
      burpsuite
      ;
  };

  talon = {
    enable = true;
    autostart = lib.mkForce true;
  };

  services.snixembed.enable = true;

  sops = {
    secrets = {
      # for systems that don't support yubikey
      "keys/ssh/ed25519" = {
        path = "${config.hostSpec.home}/.ssh/id_ed25519";
      };
    };
  };
  home.file = {
    ".ssh/id_ed25519.pub".source = lib.custom.relativeToRoot "hosts/nixos/oedo/keys/id_ed25519.pub";
  };

  xdg.configFile =
    let
      finalCss = ''
        /* Need to be adjusted to your theme. I'm using Adwaita dark theme. */
        @define-color backdrop_color #2d2d2d;
        @define-color standout_color seagreen;
        @define-color very_standout_color yellow;

        /* border around windows */
        decoration {
          border: 1px solid @very_standout_color;
          background: @very_standout_color;
        }
        decoration:backdrop {
          border: 1px solid @backdrop_color;
          background: @backdrop_color;
        }

        /* title/headerbar colors */
        headerbar.titlebar {
          background: @standout_color;
        }
        headerbar.titlebar:backdrop {
          background: @backdrop_color;
        }
      '';
    in
    {
      "gtk-3.0/gtk.css".text = finalCss;
      "gtk-4.0/gtk.css".text = finalCss;
    };
}
