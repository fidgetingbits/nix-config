{
  inputs,
  pkgs,
  # lib,
  ...
}:
# Anything that isn't already part of introdus
{
  packages = with inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system}; [
  ];
  settings = {
  };
}
