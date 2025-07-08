# Core home functionality that will only work on Linux
{
  config,
  inputs,
  #pkgs,
  lib,
  ...
}:
{
  home = rec {
    # FIXME: These need to be per the user being added to HM for multi-user systems
    # Needs to mvoe to per-user common files
    homeDirectory = config.hostSpec.home;
    username = "aa";
    sessionPath = lib.flatten (
      [
        "${homeDirectory}/scripts/"
      ]
      ++ lib.optional config.hostSpec.voiceCoding [ "${homeDirectory}/scripts/talon/" ]
      ++ lib.optional config.hostSpec.isWork inputs.nix-secrets.work.extraPaths
    );
  };
}
