{
  pkgs,
  lib,
  ...
}:
pkgs.writeShellApplication {
  name = "host-gen-pass";
  runtimeInputs = lib.attrValues {
    inherit (pkgs)
      ripgrep
      dovecot
      phraze
      gum
      yq
      ;

  };

  text = lib.readFile ./host-gen-pass.sh;
}
