{ pkgs, ... }:
let
  wine = pkgs.writeShellScriptBin "wine" ''
    # Supress unhelpful warnings
    export WINEDEBUG=-all
    # Disable looking for Gecko support
    export WINEDLLOVERRIDES="mscoree,mshtml="
    exec ${pkgs.wineWowPackages.stable}/bin/wine64 "$@"
  '';
in
{
  home.packages = [
    wine
    # pkgs.wineWowPackages.stable # 32- and 64-bit
  ];
}
