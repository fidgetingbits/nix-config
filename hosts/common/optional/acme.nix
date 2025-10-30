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
  # FIXME: This should be generic, and then each host adds their own specific domains..
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = config.hostSpec.email.letsEncrypt;
      dnsProvider = "gandiv5";
      credentialsFile = config.sops.secrets."tokens/gandi".path;
      dnsPropagationCheck = true;
    };
  };

  # FIXME: This should be switched to a function
  environment = lib.optionalAttrs config.system.impermanence.enable {
    persistence = {
      "${config.hostSpec.persistFolder}".directories = [ "/var/lib/acme" ];
    };
  };

  sops.secrets."tokens/gandi" = {
    sopsFile = "${sopsFolder}/${config.hostSpec.hostName}.yaml";
  };
}
