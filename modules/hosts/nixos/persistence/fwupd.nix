{
  config,
  lib,
  ...
}:
let
  isImpermanent = config.system ? "impermanence" && config.system.impermanence.enable;
in
{
  config = lib.mkIf (config.services.fwupd.enable && isImpermanent) {
    environment.persistence.${config.hostSpec.persistFolder}.directories = [
      "/var/cache/fwupd"
      "/var/lib/fwupd"
    ];
  };
}
