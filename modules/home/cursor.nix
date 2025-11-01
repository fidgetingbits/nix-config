{
  pkgs,
  lib,
  config,
  ...
}:
lib.mkIf config.hostSpec.isAutoStyled {
  stylix = {
    cursor = lib.mkForce {
      package = pkgs.rose-pine-cursor;
      name = "BreezeX-RosePine-Linux";
      size = 30;
    };
    # cursor = lib.mkForce {
    #   name = "Breeze_Hacked";
    #   package = pkgs.breeze-hacked-cursor-theme;
    #   size = 30;
    # };
  };
}
