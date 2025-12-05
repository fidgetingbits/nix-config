{ stdenv, pkgs, ... }:
stdenv.mkDerivation {
  name = "neovim-python-scripts";
  buildInputs = [ (pkgs.python3.withPackages (pythonPackages: lib.attrValues { })) ];
  dontUnpack = true;
  installPhase = ''
    install -Dm755 ${./json2nix.py} $out/bin/json2nix
  '';
}
