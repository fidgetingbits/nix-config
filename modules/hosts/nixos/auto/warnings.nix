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

      # These are stylix warnings that I can't fix myself, and don't care
      # FIXME: These could be fixed upstream instead of ignoring :P
      "stylix: qt: `config.stylix.targets.qt.platform` other than 'qtct' are currently unsupported: gnome. Support may be added in the future."
      "The value `gnome` for option `qt.platformTheme.name` is deprecated. Use `adwaita` instead."
      "stylix: firefox: `config.stylix.targets.firefox.profileNames` is not set."

      # This seems to come from some external module? I don't set nixpkgs in HM
      "You have set either `nixpkgs.config` or `nixpkgs.overlays` while using `home-manager.useGlobalPkgs`."

      # This has nothing directly to do with our config afaict
      "Skipping hindent because it "
      "Skipping phpstan because it "
    ];
  };
}
