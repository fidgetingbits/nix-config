{
  inputs,
  config,
  lib,
  ...
}:
let
  cfg = config.voiceCoding;
in
{
  imports = [ inputs.talon-nix.nixosModules.talon ];
  options.voiceCoding = {
    enable = lib.mkEnableOption "Enable voice-coding features";
  };
  config = lib.mkIf cfg.enable {
    services.joycond.enable = true;
    programs.talon.enable = true;
  };
}
