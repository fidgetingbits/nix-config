{
  pkgs,
  lib,
  ...
}:

{
  home.packages = lib.attrValues {
    inherit (pkgs)
      # document editing
      libreoffice # word, excel, etc

      # document conversion
      pandoc # doc -> pdf
      tetex # latex pdf engine for pandoc
      ;
  };
}
