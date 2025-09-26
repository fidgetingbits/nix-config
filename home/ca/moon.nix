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
          "fcitx5"

          # Maybe more role-specific stuff
          "document.nix" # document editing
          "gui-utilities.nix" # core for any desktop
        ])
    )
  );

  home.packages = builtins.attrValues {
  };

  xdg.autostart = {
    enable = true;
    #readOnly = true;
    entries = [
      "${pkgs.firefox}/share/applications/firefox.desktop"
    ];
  };

}
