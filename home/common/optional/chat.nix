{
  pkgs,
  ...
}:

{
  home.packages = builtins.attrValues { inherit (pkgs) signal-desktop; };
}
