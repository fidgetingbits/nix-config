{
  inputs,
  config,
  lib,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.acme;
  sopsFolder = (lib.toString inputs.nix-secrets) + "/sops";
in
{
  options.${namespace}.acme = {
    enable = lib.mkOption {
      type = lib.types.bool;
      # Enabled when any nginxProxy service is defined — each one requests
      # an ACME cert for its subdomain.
      default = lib.length config.services.nginxProxy.services > 0;
      description = "Enable acme cert handling";
    };
  };
  config = lib.mkIf cfg.enable {
    security.acme = {
      acceptTerms = true;
      defaults = {
        email = config.hostSpec.email.letsEncrypt;
        dnsProvider = "gandiv5";
        credentialFiles = {
          "GANDIV5_PERSONAL_ACCESS_TOKEN_FILE" = config.sops.secrets."tokens/gandi".path;
        };
        dnsPropagationCheck = true;
      };
    };

    environment = lib.optionalAttrs config.introdus.impermanence.enable {
      persistence = {
        "${config.hostSpec.persistFolder}".directories = [ "/var/lib/acme" ];
      };
    };

    sops.secrets."tokens/gandi" = {
      sopsFile = "${sopsFolder}/${config.hostSpec.hostName}.yaml";
    };
  };
}
