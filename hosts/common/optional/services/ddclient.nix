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
  services.ddclient = {
    enable = true;
    zone = config.hostSpec.domain;
    domains = [ "${config.hostSpec.hostName}.${config.hostSpec.domain}" ];
    passwordFile = config.sops.secrets."tokens/gandi".path;
    extraConfig = ''
      use-personal-access-token=yes
    '';

  };

  environment = lib.optionalAttrs config.system.impermanence.enable {
    persistence = {
      "${config.hostSpec.persistFolder}".directories = [
        {
          # NOTE: systemd Dynamic User requires /var/lib/private to be 0700. See impermanence module
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
}
