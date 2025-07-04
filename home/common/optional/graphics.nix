{ pkgs, ... }:
{
  home.packages = builtins.attrValues {
    inherit (pkgs)
      gimp # image editor
      drawio # vector diagram editor
      drawio-export-all # helper for mass image extraction
      img-cat # image to ansi
      ;
  };
}
