{
  lib,
  stdenv,
  fetchgit,
}:
let
  pname = "ghidra-gruvbox-theme";
in
stdenv.mkDerivation {
  name = pname;
  version = "d6dc573532e6a4ac4c294cc80c9217fcfa90348f";
  src = fetchgit {
    url = "https://github.com/kStor2poche/ghidra-gruvbox-theme";
    hash = "sha256-2OzWZBKDdWcJ6CJ8Q5PbtqUHtpdHVtIDdtwaiuB/LLo=";
  };
  strictDeps = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    install -m444 -Dt $out/ *.theme
    runHook postInstall
  '';
  meta = {
    license = lib.licenses.mit;
    longDescription = ''
      The whole suite of gruvbox variants, ported to ghidra!
      ```
    '';

    maintainers = [ lib.maintainers.fidgetingbits ];
  };
}
