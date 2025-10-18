{
  config,
  lib,
  pkgs,
  writeShellScriptBin,
}:
let
  dependencies = [
    pkgs.jq
    pkgs.jtbl
    pkgs.fzf
    config.programs.hyprland.package
  ];
in
writeShellScriptBin "hypr-binds" ''
  export PATH=${lib.makeBinPath dependencies}:$PATH
''
+ (builtins.readFile ./hypr-binds.sh)
