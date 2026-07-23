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

  # FIXME: stylix
  # > In /nix/store/0vm3mzhmj0qpzsn34xwy4xmy1xw572p3-stylix-kde-apply-plasma-theme/bin/stylix-kde-apply-plasma-theme line 7:
  # > username=admin
  # > ^------^ SC2209 (warning): Use var=$(command) to assign output (or quote to assign string).
  stylix.targets.kde.enable = false;
}
