{ stdenv, pkgs, ... }:
stdenv.mkDerivation {
  name = "neovim-python-scripts";
  buildInputs = [
    (pkgs.python312.withPackages (
      pythonPackages: builtins.attrValues { inherit (pythonPackages) pynvim; }
    ))
  ];
  dontUnpack = true;
  installPhase = ''
    install -Dm755 ${./scripts/neovim-autocd.py} $out/bin/neovim-autocd
    install -Dm755 ${./scripts/neovim-openfile.py} $out/bin/neovim-openfile
    install -Dm755 ${./scripts/neovim-openfile-buf.py} $out/bin/neovim-openfile-buf
    install -Dm755 ${./scripts/neovim-sudoedit.py} $out/bin/neovim-sudoedit
    install -Dm755 ${./scripts/neovim-diff.py} $out/bin/neovim-diff
    install -Dm755 ${./scripts/neovim-man.py} $out/bin/neovim-man
    install -Dm755 ${./scripts/neovim-change-bg-color.py} $out/bin/neovim-change-bg-color
  '';
}
