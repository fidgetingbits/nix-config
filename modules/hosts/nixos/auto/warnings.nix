{ config, lib, ... }:
{
  # mostly copied from https://git.uninsane.org/colin/nix-files/src/branch/master/modules/warnings.nix
  options = {
    configOptions.silencedWarnings = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        list of `config.warnings` values you want to ignore, verbatim.
      '';
    };
    warnings = lib.mkOption {
      # Fuzzy match warnings since multi-user password hash warnings (for example) are too long
      apply = lib.filter (
        warning: !(lib.any (silenced: lib.hasInfix silenced warning) config.configOptions.silencedWarnings)
      );
    };
  };
  config = {
    configOptions.silencedWarnings = [
      "If multiple of these password options are set at the same time then a"
    ];
  };
}
