{
  lib,
  ...
}:
{
  imports = (
    map lib.custom.relativeToRoot (
      # FIXME: remove after fixing user/home values in HM
      [
        "home/common/core"
        "home/common/core/nixos.nix"
      ]
      ++ (map (f: "home/common/optional/${f}") [
        "ssh"
        "sops.nix"
      ])
    )
  );

  home.packages = builtins.attrValues {

  };

}
