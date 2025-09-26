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
    protocol = "gandi";
    zone = config.hostSpec.domain;
    # NOTE: This record must already exist on gandi in order to update it, otherwise will 404
    domains = [ "${config.hostSpec.hostName}.${config.hostSpec.domain}" ];
    passwordFile = config.sops.secrets."tokens/gandi".path;
    username = "token";
    extraConfig = ''
      use-personal-access-token=yes
      usev4=webv4
      usev6=disabled
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
