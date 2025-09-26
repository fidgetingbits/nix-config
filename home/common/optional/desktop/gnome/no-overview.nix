{ pkgs, ... }:
{
  home.packages = [
    pkgs.gnomeExtensions.no-overview
  ];

  dconf.settings = {
    "org/gnome/shell"."enabled-extensions" = [
      pkgs.gnomeExtensions.no-overview.extensionUuid
    ];
  };
}
