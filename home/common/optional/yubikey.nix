{ pkgs, lib, ... }:
{
  home.packages = lib.attrValues {
    inherit (pkgs)
      yubioath-flutter
      yubikey-personalization
      yubikey-manager
      yubico-piv-tool
      ;
  };
}
