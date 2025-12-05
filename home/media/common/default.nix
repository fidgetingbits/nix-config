{ inputs, lib, ... }:
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

  home.file = {
    # Avatar used by login managers like SDDM (must be PNG)
    ".face.icon".source = "${inputs.nix-assets}/images/avatars/corgi-boba.png";
  };
}
