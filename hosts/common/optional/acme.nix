{
  inputs,
  config,
  lib,
  ...
}:
let
  sopsFolder = (builtins.toString inputs.nix-secrets) + "/sops";
in
{
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

  environment = lib.optionalAttrs config.system.impermanence.enable {
    persistence = {
      "${config.hostSpec.persistFolder}".directories = [ "/var/lib/acme" ];
    };
  };

  sops.secrets."tokens/gandi" = {
    sopsFile = "${sopsFolder}/${config.hostSpec.hostName}.yaml";
  };
}
