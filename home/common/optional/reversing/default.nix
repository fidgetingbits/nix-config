{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = lib.custom.scanPaths ./.;

  home.packages = lib.optionals config.hostSpec.isWork (
    builtins.attrValues {
      inherit (pkgs)
        #ida-free
        ida-pro
        diaphora
        #  binaryninja
        ;
    }
  );
}
