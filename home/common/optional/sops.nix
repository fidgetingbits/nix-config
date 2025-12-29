{
  lib,
  inputs,
  config,
  osConfig,
  secrets,
  ...
}:
let
  sopsFolder = (builtins.toString inputs.nix-secrets) + "/sops";
  homeDirectory = config.home.homeDirectory;
  yubikeys = [
    "dade"
    "drzt"
    "dark"
    "derp"
    "desi"
  ];

  # Linux: Exists in $XDG_RUNTIME_DIR/id_dade
  # Darwin: Exists in $(getconf DARWIN_USER_TEMP_DIR)
  #   ex: /var/folders/pp/t8_sr4ln0qv5879cp3trt1b00000gn/T/id_dade
  yubikeySecrets = lib.optionalAttrs osConfig.hostSpec.useYubikey (
    {
      "keys/u2f" = {
        path = "${homeDirectory}/.config/Yubico/u2f_keys";
      };
    }
    // lib.attrsets.mergeAttrsList (
      lib.lists.map (name: {
        "keys/ssh/${name}" = {
          sopsFile = "${sopsFolder}/shared.yaml";
          path = "${homeDirectory}/.ssh/id_${name}";
        };
      }) yubikeys
    )
  );

  workSecrets = "${sopsFolder}/work.yaml";
  workSopsSecrets = lib.optionalAttrs osConfig.hostSpec.isWork (
    secrets.work.sops workSecrets homeDirectory sopsFolder
  );
in
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];
  sops = {
    # This is pre-populated by the host sops module
    age.keyFile = "${homeDirectory}/.config/sops/age/keys.txt";

    defaultSopsFile = "${sopsFolder}/${osConfig.hostSpec.hostName}.yaml";
    validateSopsFiles = false;

    secrets = {
      "keys/git-crypt" = {
        sopsFile = "${sopsFolder}/shared.yaml";
      };
    }
    # // lib.optionalAttrs osConfig.hostSpec.isDevelopment {
    #   "tokens/openai" = {
    #     sopsFile = "${sopsFolder}/shared.yaml";
    #     path = "${homeDirectory}/.config/openai/token";
    #   };
    # }
    // lib.optionalAttrs osConfig.hostSpec.isWork {
      # FIXME(secrets): Need an activation script to build a config.yml using multiple files (ie: work and personal)
      "config/glab" = {
        sopsFile = "${sopsFolder}/development.yaml";
        path = "${homeDirectory}/.config/glab/config.yml";
      };
    }
    // yubikeySecrets
    // workSopsSecrets;
  };
}
