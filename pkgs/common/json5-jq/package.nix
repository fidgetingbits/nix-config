{ stdenv, fetchFromGitHub }:
stdenv.mkDerivation {
  name = "json5-jq";

  src = fetchFromGitHub {
    owner = "wader";
    repo = "json5.jq";
    rev = "ac46e5b58dfcdaa44a260adeb705000f5f5111bd";
    sha256 = "sha256-xBVnbx7L2fhbKDfHOCU1aakcixhgimFqz/2fscnZx9g=";
  };

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/share
    cp json5.jq $out/share/json5.jq
  '';
}
