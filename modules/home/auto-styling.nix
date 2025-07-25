{ lib, config, ... }:
{
  config = lib.mkIf config.hostSpec.isAutoStyled {
    # Defined here because zellij is core, but stylix isn't so can infinite recurse
    #stylix.targets.zellij.enable = true;
  };
}
