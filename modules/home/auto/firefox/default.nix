{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
# See introdus for main shared settings
lib.mkIf config.programs.firefox.enable {
  introdus.firefox = {
    extensions = [ (import ./extensions.nix { inherit pkgs inputs lib; }) ];
    search = [ (import ./search.nix { inherit lib pkgs; }) ];
  };
}
