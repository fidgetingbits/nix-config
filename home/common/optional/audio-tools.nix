{ pkgs, lib, ... }:
{
  home.packages = lib.attrValues { inherit (pkgs) obs-studio audacity; };
}
