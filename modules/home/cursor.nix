{
  inputs,
  pkgs,
  lib,
  osConfig,
  ...
}:
{
  # This shuts up nix flake check
  imports = lib.optional (!(osConfig ? stylix)) inputs.stylix.homeManagerModules.stylix;
  config = lib.mkIf osConfig.hostSpec.isAutoStyled {
    stylix = {
      # cursor = (
      #   lib.mkOverride 200 {
      #     package = pkgs.rose-pine-cursor;
      #     name = "BreezeX-RosePine-Linux";
      #     size = 30;
      #   }
      # );

      cursor = lib.mkForce {
        name = "Breeze_Hacked";
        package = pkgs.breeze-hacked-cursor-theme;
        size = 30;
      };
    };
  };
}
