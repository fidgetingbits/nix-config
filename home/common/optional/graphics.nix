{ pkgs, lib, ... }:
{
  home.packages = lib.attrValues {
    inherit (pkgs)
      gimp # image editor
      drawio # vector diagram editor
      img-cat # image to ansi
      chafa # png to sixel
      ;
    inherit (pkgs.introdus)
      drawio-export-all # helper for mass image extraction
      ;
  };
}
