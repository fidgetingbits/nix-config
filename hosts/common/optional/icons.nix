# A set of icon theme packs that work with noctalia when gnome isn't installed
{
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = lib.attrValues {
    inherit (pkgs)
      adwaita-icon-theme
      hicolor-icon-theme
      ;

    # Qt's wayland QPA leaves QIcon::themeName empty so noctalia falls through
    # to hicolor and can't find generic icons like user-desktop. The gtk3
    # platform theme reads gtk-icon-theme-name; ship breeze so that resolves.
    inherit (pkgs.kdePackages) breeze-icons;

  };
  # FIXME: This fails even with lib.mkForce because of qt5.nix conflict
  # environment.sessionVariables = {
  #   # Make Qt resolve icon themes via GTK settings instead of defaulting to
  #   # hicolor-only on the wayland QPA (see breeze-icons above).
  #   QT_QPA_PLATFORMTHEME = "gtk3";
  # };
}
