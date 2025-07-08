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
        "#ssh.nix"
      ])
    )
  );

  home.packages = builtins.attrValues {

  };

  #services.yubikey-touch-detector.enable = true;
  #services.yubikey-touch-detector.notificationSound = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

}
