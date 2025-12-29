{
  #  inputs,
  lib,
  osConfig,
  ...
}:
{
  # imports = [
  #   inputs.stylix.homeModules.stylix
  # ];

  config = lib.mkIf osConfig.hostSpec.isAutoStyled {
    stylix.targets.zellij.enable = true;
  };

}
