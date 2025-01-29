{ lib, stdenv, ... }:
let
  pname = "zsh-neovim-autocd";
  install_path = "share/zsh/${pname}";
in
stdenv.mkDerivation {
  name = pname;
  strictDeps = true;
  dontBuild = true;
  dontUnpack = true;
  runtimeInputs = [ ];
  installPhase = ''
    install -m755 -D ${./zsh-neovim-autocd.plugin.zsh} $out/${install_path}/${pname}.plugin.zsh
  '';
  meta = {
    license = lib.licenses.mit;
    longDescription = ''
      This Zsh plugin calls a utility to automatically change the containing neovim into the working directory.

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
