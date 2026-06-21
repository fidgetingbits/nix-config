{
  config,
  lib,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.debug;
in
{
  options.${namespace}.debug = {
    enable = lib.mkEnableOption "Toggle debug settings for system";
  };

  config = lib.mkIf cfg.enable {
    boot.kernelParams = [
      "systemd.log_level=debug"
      "systemd.log_target=journal"
    ];
  };
}
