{
  stdenv,
  pkgs,
  lib,
  ...
}:
# https://gist.githubusercontent.com/pshirshov/2b5744abbcfae376a87a80bc501a0866/raw/2f15ff5c2715275e42d22691b8eca2969bbc85cf/nixos-extract-initrd.py
stdenv.mkDerivation {
  name = "nixos-extract-initrd";
  buildInputs = [ (pkgs.python3.withPackages (pythonPackages: lib.attrValues { })) ];
  dontUnpack = true;
  installPhase = ''
    install -Dm755 ${./nixos-extract-initrd.py} $out/bin/nixos-extract-initrd
  '';
}
