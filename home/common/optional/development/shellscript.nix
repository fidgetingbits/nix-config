{ pkgs, lib, ... }:
{
  home.packages = lib.attrValues { inherit (pkgs) shellcheck shfmt; };
}
