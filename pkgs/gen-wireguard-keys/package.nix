{
  pkgs,
  lib,
}:
pkgs.writeShellApplication {
  name = "gen-wireguard-keys";
  runtimeInputs = lib.attrValues {
    inherit (pkgs)
      gum
      wireguard-tools
      rosenpass
      sops
      ;
  };
  text = lib.readFile ./gen-wireguard-keys.sh;
}
