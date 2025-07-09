# Core home functionality that will only work on Linux
{
  config,
  inputs,
  #pkgs,
  lib,
  ...
}:
let
  homeDirectory = config.hostSpec.home;
in
{
  home = {
    sessionPath = lib.flatten (
      [
        "${homeDirectory}/scripts/"
      ]
      ++ lib.optional config.hostSpec.voiceCoding [ "${homeDirectory}/scripts/talon/" ]
      ++ lib.optional config.hostSpec.isWork inputs.nix-secrets.work.extraPaths
    );
  };
}
