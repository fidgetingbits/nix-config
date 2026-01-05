{
  osConfig,
  lib,
  pkgs,
  ...
}:
{
  imports = lib.custom.scanPaths ./.;

  home.packages = lib.optionals osConfig.hostSpec.isWork (
    lib.attrValues {
      inherit (pkgs.introdus)
        diaphora
        ;
    }
  );
}
