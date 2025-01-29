{
  lib,
  pkgs,
  ...
}:
{
  home = {
    packages = builtins.attrValues (
      {
        inherit (pkgs)
          clang-tools # Provides clangd lsp
          ;
      }
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        inherit (pkgs)
          bear # For creating compilation databases for clangd
          ;
      }
    );
    file.".clang-format".source =
      let
        yamlFormat = pkgs.formats.yaml { };
      in
      yamlFormat.generate "clang-format" {
        BasedOnStyle = "LLVM";
        IndentWidth = 4;
        IndentCaseLabels = true;
        AlignConsecutiveDeclarations = true;
      };
  };
}
