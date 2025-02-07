{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
}:

stdenv.mkDerivation rec {
  pname = "midgetpack";
  version = "0.1.1";

  src = fetchFromGitHub {
    owner = "arisada";
    repo = "midgetpack";
    rev = "v${version}";
    sha256 = "sha256-gQefVALbX2RTpW9WzxB9f3E7WT3nCdBgLcApn3da4TA=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [
    stdenv.cc.libc.static
  ];

  cmakeDir = "..";

  cmakeFlags = [
    "-DCMAKE_C_FLAGS=-static" # prevent using -llibgcc_s which will fail
  ];

  installPhase = ''
    mkdir -p $out/bin
    install -m 755 src/packer/midgetpack $out/bin
  '';

  meta = {
    description = "Midgetpack is a binary packer for ELF binaries to protect your assets (tools, exploits) when using
 them on untrusted systems..";
    license = lib.licenses.bsd2;
    homepage = "https://github.com/arisada/midgetpack";
    mainProgram = "midgetpack";

  };
}
