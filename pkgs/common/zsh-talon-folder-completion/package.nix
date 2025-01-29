{
  lib,
  pkgs,
  stdenv,
}:
let
  pname = "zsh-talon-folder-completion";
  install_path = "share/zsh/${pname}";
in
stdenv.mkDerivation {
  name = pname;
  strictDeps = true;
  dontBuild = true;
  dontUnpack = true;
  nativeBuildInputs = [ pkgs.makeWrapper ];
  runtimeInputs = [ pkgs.fswatch ];

  installPhase = ''
    install -m755 -D ${./zsh-talon-folder-completion.plugin.zsh} $out/${install_path}/${pname}.plugin.zsh

  '';
  meta = {
    license = lib.licenses.mit;
    longDescription = ''
      This Zsh plugin uses thooks to populate files watched by talon with the name of directory contents.

      To install the ${pname} plugin you can add the following to your `programs.zsh.plugins` list:

      ```nix
        programs.zsh.plugins = [
      {
      name = "${pname}";
      src = "''${pkgs.${pname}}/${install_path}";
      }
      ];
      ```
    '';

    maintainers = [ lib.maintainers.fidgetingbits ];
  };
}
