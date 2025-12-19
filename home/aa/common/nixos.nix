# Core home functionality that will only work on Linux
{
  config,
  lib,
  secrets,
  ...
}:
let
  homeDirectory = config.home.homeDirectory;
in
{
  home = {
    sessionPath = lib.flatten (
      [
        "${homeDirectory}/scripts/"
      ]
      ++ lib.optional config.hostSpec.voiceCoding [ "${homeDirectory}/scripts/talon/" ]
      ++ lib.optional config.hostSpec.isWork secrets.work.extraPaths
    );
  };
}
