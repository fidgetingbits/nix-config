{
  pkgs,
  lib,
  config,
  ...
}:
{
  services.opensnitch = {
    enable = false; # Temporary until I setup sane rule baseline
    upstreamDefaults = true;
    settings = {
      DefaultAction = "allow";
      InterceptUnknown = true;
      LogLevel = 1;
    };
  };

  # Packages
  environment = {
    systemPackages = lib.attrValues {
      inherit (pkgs)
        opensnitch-ui
        ;
    };
  }
  // lib.optionalAttrs config.introdus.impermanence.enable {
    persistence.${config.hostSpec.persistFolder}.directories =
      lib.mkIf config.introdus.impermanence.enable
        [
          "/var/lib/opensnitch"
        ];
  };
}
