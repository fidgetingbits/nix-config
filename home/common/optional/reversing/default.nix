{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = lib.custom.scanPaths ./.;

  home.packages = lib.optionals config.hostSpec.isWork (
    lib.attrValues {
      inherit (pkgs)
        #ida-free
        #ida-pro
        diaphora
        #  binaryninja
        ;
    }
  );
}
