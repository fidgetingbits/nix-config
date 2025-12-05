{
  #pkgs,
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
      ])
    )
  );

  home.packages = lib.attrValues {

  };

  #services.yubikey-touch-detector.enable = true;
  #services.yubikey-touch-detector.notificationSound = true;
}
