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
  };
}
