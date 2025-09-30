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

  programs.firefox = {
    policies.OfferToSaveLogins = lib.mkForce true;
    profiles.default = {
      settings."signon.rememberSignons" = lib.mkForce true;
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
            ];
          }
        ];
      };
    };
  };

  xdg.autostart = {
    enable = true;
    #readOnly = true;
    entries = [
      "${pkgs.firefox}/share/applications/firefox.desktop"
    ];
  };

}
