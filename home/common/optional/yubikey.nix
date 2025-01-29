{ pkgs, ... }:
{
  home.packages = builtins.attrValues {
    inherit (pkgs)
      yubioath-flutter
      yubikey-personalization
      yubikey-personalization-gui
      yubikey-manager
      yubikey-manager-qt
      yubico-piv-tool
      ;
  };
}
