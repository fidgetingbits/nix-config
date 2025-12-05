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
        "sops.nix"
      ])
    )
  );

  home.packages = lib.attrValues {

  };

  system.ssh-motd.enable = true;

}
