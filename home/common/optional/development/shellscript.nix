{ pkgs, ... }:
{
  home.packages = builtins.attrValues { inherit (pkgs) shellcheck shfmt; };
}
