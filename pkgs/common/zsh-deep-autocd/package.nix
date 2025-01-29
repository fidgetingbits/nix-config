{ lib, stdenv, ... }:
let
  pname = "zsh-deep-autocd";
  install_path = "share/zsh/${pname}";
in
stdenv.mkDerivation {
  name = pname;
  strictDeps = true;
  dontBuild = true;
  dontUnpack = true;
  installPhase = ''
    install -m755 -D ${./zsh-deep-autocd.plugin.zsh} $out/${install_path}/${pname}.plugin.zsh
  '';
  meta = {
    license = lib.licenses.mit;
    longDescription = ''
      This Zsh plugin creates a function to automatically cd into the first nested directory containing a file.

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
