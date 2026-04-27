{
  lib,
  config,
  ...
}:
lib.mkIf config.services.postgresql.enable {
  # FIXME: Enable something to backup atuin/postgresql. See mic92 postgresqlBackup
  environment = lib.optionalAttrs config.introdus.impermanence.enable {
    persistence = {
      "${config.hostSpec.persistFolder}".directories = [ "/var/lib/postgresql" ];
    };
  };
}
