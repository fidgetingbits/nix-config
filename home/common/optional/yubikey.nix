{ pkgs, ... }:
{
  home.packages = builtins.attrValues {
    inherit (pkgs)
      yubioath-flutter
      yubikey-personalization
      yubikey-manager
      yubico-piv-tool
      ;
  };
}
