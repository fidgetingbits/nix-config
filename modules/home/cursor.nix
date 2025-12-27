{
  # pkgs,
  lib,
  config,
  ...
}:
lib.mkIf config.hostSpec.isAutoStyled {
  # FIXME: This is busted
  #error (ignored): The option `home-manager.users.aa.stylix' does not exist. Definition values:
  #- In `/nix/store/2qhywi14paiw3s90229mhbrkpizjp8d7-source/modules/home/cursor.nix':
  #  stylix = {
  #    cursor = (
  #      lib.mkOverride 200 {
  #        package = pkgs.rose-pine-cursor;
  #        name = "BreezeX-RosePine-Linux";
  #        size = 30;
  #      }
  #    );

  # cursor = lib.mkForce {
  #   name = "Breeze_Hacked";
  #   package = pkgs.breeze-hacked-cursor-theme;
  #   size = 30;
  # };
  # };
}
