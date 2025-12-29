# Core home functionality that will only work on Linux
{
  config,
  osConfig,
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
      ++ lib.optional osConfig.hostSpec.voiceCoding [ "${homeDirectory}/scripts/talon/" ]
      ++ lib.optional osConfig.hostSpec.isWork secrets.work.extraPaths
    );
  };
}
