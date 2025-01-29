{ pkgs, ... }:
{
  home.packages = builtins.attrValues { inherit (pkgs) obs-studio audacity; };
}
