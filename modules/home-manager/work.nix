{ config, lib, ... }:
let
  cfg = config.settings.work;
  homeDirectory = config.home.homeDirectory;
in
{
  options.settings.work = {
    enable = lib.mkEnableOption "Host is used for work";
  };
  config = lib.mkIf cfg.enable {
    # Set some environment variables to help automation for projects
    home = {
      sessionVariables.WORK_SOURCE = "${homeDirectory}/work/source/";
    };
  };
}
