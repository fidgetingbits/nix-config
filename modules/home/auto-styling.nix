{
  lib,
  config,
  ...
}:
{
  #  imports = [
  #    inputs.stylix.homeModules.stylix
  #  ];

  config = lib.mkIf config.hostSpec.isAutoStyled {
    stylix.targets.zellij.enable = true;
  };

}
