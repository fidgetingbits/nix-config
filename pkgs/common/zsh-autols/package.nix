{ lib, stdenv }:
let
  pname = "zsh-autols";
  install_path = "share/zsh/${pname}";
in
stdenv.mkDerivation {
  name = pname;
  strictDeps = true;
  dontBuild = true;
  dontUnpack = true;
  installPhase = ''
    install -m755 -D ${./zsh-autols.plugin.zsh} $out/${install_path}/${pname}.plugin.zsh
  '';
  meta = {
    license = lib.licenses.mit;
    longDescription = ''
      This Zsh plugin creates a hook to automatically ls every time a directory is entered.

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
