{
  pkgs,
  lib,
  ...
}:
{
  home.packages = lib.attrValues {
    inherit (pkgs)
      copyq
      ;
  };
}
