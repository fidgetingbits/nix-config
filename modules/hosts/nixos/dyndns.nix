{
  inputs,
  config,
  lib,
  ...
}:
let
  cfg = config.services.dyndns;
  sopsFolder = (builtins.toString inputs.nix-secrets) + "/sops";
in
{
  options = {
    services.dyndns = {
      enable = lib.mkEnableOption "dyndns";
      subDomain = lib.mkOption rec {
        type = lib.types.str;
        default = config.hostSpec.hostName;
        example = default;
        description = "Subdomain to update record for. The `foo` in `foo.example.com`.";
      };
    };

  };
  config = lib.mkIf cfg.enable {
    services.ddclient = {
      enable = true;
      protocol = "gandi";
      zone = config.hostSpec.domain;
      # NOTE: This record must already exist on gandi in order to update it,
      # otherwise will 404
      domains = [ "${cfg.subDomain}.${config.hostSpec.domain}" ];
      passwordFile = config.sops.secrets."tokens/gandi".path;
      username = "token";
      extraConfig = ''
        use-personal-access-token=yes
        usev4=webv4
        usev6=disabled
      '';
    };

    systemd.services.ddclient = {
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      startLimitIntervalSec = 1;
      startLimitBurst = 50;
    };

    environment =
      lib.optionalAttrs (config.system ? impermanence && config.system.impermanence.enable)
        {
          persistence = {
            "${config.hostSpec.persistFolder}".directories = [
              {
                # NOTE: systemd Dynamic User requires /var/lib/private to be
                # 0700. See impermanence module
                directory = "/var/lib/private/ddclient";
                user = "nobody";
                group = "nogroup";
              }
            ];
          };
        };

    sops.secrets."tokens/gandi" = {
      sopsFile = "${sopsFolder}/${config.hostSpec.hostName}.yaml";
    };
  };
}
