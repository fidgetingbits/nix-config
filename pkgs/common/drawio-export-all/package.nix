{ stdenv, pkgs, ... }:
stdenv.mkDerivation {
  name = "drawio-export-all";
  buildInputs = [
    pkgs.drawio
    pkgs.imagemagick
    (pkgs.python3.withPackages (pythonPackages: [ ]))
  ];
  dontUnpack = true;
  installPhase = ''
    install -Dm755 ${./drawio-export-all.py} $out/bin/drawio-export-all.py
  '';
}
