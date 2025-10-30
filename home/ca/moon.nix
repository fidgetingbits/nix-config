{
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
          "xdg.nix"
          "gpg.nix"
          "ghostty.nix"
          "media.nix"
          "networking/protonvpn.nix"

          "desktop/gnome"
          "gnome-terminal.nix"

          # Maybe more role-specific stuff
          "document.nix" # document editing
          "gui-utilities.nix" # core for any desktop
        ])
    )
  );

  home.packages = builtins.attrValues {
    inherit (pkgs)
      google-chrome
      ;
  };

  # FIXME(firefox): Add extensions
  programs.firefox = {
    policies = {
      DisableFirefoxAccounts = lib.mkForce true;
    };
    profiles.default = {
      settings = {
        # "signon.rememberSignons" = lib.mkForce "false";
        "layout.css.devPixelsPerPx" = 2.4; # Hi DPI is already 2.0, but extension icons are small on TV
      };
      # Tweaks for Firefox ui/layout
      # Try to make the extension icons bigger
      # userChrome = ''
      #   /* Size of tool bar extension icons */
      #   .toolbarbutton-icon {
      #     width: 40px !important;
      #     height: 40px !important;
      #   }
      # '';
      bookmarks = {
        force = true;
        settings = [
          {
            name = "Bookmarks Toolbar";
            toolbar = true;
            bookmarks = [
              {
                name = "Jellyfin";
                url = "http://localhost:8096";
              }
              {
                name = "Netflix";
                url = "https://www.netflix.com";
              }
              {
                name = "YouTube";
                url = "https://www.youtube.com";
              }
              {
                name = "Photos";
                url = "https://photos.google.com";
              }
            ];
          }
        ];
      };
    };
  };

  # Keep firefox running if it's closed
  systemd.user.services.firefox = {
    Unit = {
      description = "Firefox Browser";
      After = [
        "graphical-session.target"
        "graphical-session-pre.target"
      ];
      PartOf = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      ExecStart = "/home/ca/.nix-profile/bin/firefox";
      Restart = "always";
      RestartSec = 5;
    };
  };

  # xdg.autostart = {
  #   enable = true;
  #   #readOnly = true;
  #   entries = [
  #     "${pkgs.firefox}/share/applications/firefox.desktop"
  #   ];
  # };

  # Make cursor bigger than defualt
  stylix = {
    cursor = lib.mkOrder 10 {
      name = "catppuccin-mocha-light-cursors";
      package = pkgs.catppuccin-cursors.mochaLight;
      size = 40;
    };
  };
}
