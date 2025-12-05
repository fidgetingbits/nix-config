{
  #config,
  lib,
  pkgs,
  writeShellScriptBin,
}:
let
  dependencies = [
    pkgs.jq
    pkgs.jtbl
    pkgs.fzf
    # FIXME: This should ideally use whatever version of hyprland is already installed,
    # but config.programs.hyprland.package isn't working
    pkgs.unstable.hyprland
  ];
in
writeShellScriptBin "hypr-binds" (
  ''
    export PATH=${lib.makeBinPath dependencies}:$PATH
  ''
  + (lib.readFile ./hypr-binds.sh)
)
