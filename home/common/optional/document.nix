{
  pkgs,
  ...
}:

{
  home.packages = builtins.attrValues {
    inherit (pkgs)
      # document editing
      libreoffice # word, excel, etc

      # document conversion
      # NOTE: tetex fails on darwin
      pandoc # doc -> pdf
      tetex # latex pdf engine for pandoc
      ;
  };
}
