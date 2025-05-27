{ pkgs, ... }:
{
  home.packages = builtins.attrValues {
    inherit (pkgs)
      yubioath-flutter
      yubikey-personalization
      yubikey-personalization-gui
      yubikey-manager
      yubico-piv-tool
      ;
  };
}
