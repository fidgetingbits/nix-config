{ config, lib, ... }:
{
  # mostly copied from https://git.uninsane.org/colin/nix-files/src/branch/master/modules/warnings.nix
  options = with lib; {
    configOptions.silencedWarnings = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        list of `config.warnings` values you want to ignore, verbatim.
      '';
    };
    # FIXME: This should do regex-based filter instead
    warnings = mkOption {
      apply = lib.filter (w: !(lib.elem w config.configOptions.silencedWarnings));
    };
  };
}
