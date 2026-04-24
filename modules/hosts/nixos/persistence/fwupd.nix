{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.services.fwupd.enable && config.introdus.impermanence.enable) {
    environment.persistence.${config.hostSpec.persistFolder}.directories = [
      "/var/cache/fwupd"
      "/var/lib/fwupd"
    ];
  };
}
