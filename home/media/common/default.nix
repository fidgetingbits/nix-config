{ lib, ... }:
{
  imports = (
    map lib.custom.relativeToRoot (
      map (f: "home/common/optional/${f}") [
        "ghostty.nix"
        "networking/protonvpn.nix"
      ]
    )
  );

  home.packages = lib.attrValues {

  };
}
