{
  config,
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

  #services.yubikey-touch-detector.enable = true;
  #services.yubikey-touch-detector.notificationSound = true;
  sops = {
    secrets = {
      # for systems that don't support yubikey
      "keys/ssh/ed25519" = {
        path = "${config.home.homeDirectory}/.ssh/id_ed25519";
      };
      "keys/ssh/ed25519_pub" = {
        path = "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
      };
    };
  };

}
