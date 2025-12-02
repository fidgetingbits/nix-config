{
  lib,
  inputs,
  config,
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
  yubikeySecrets = lib.optionalAttrs config.hostSpec.useYubikey (
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
  workSopsSecrets = lib.optionalAttrs config.hostSpec.isWork (
    inputs.nix-secrets.work.sops workSecrets homeDirectory sopsFolder
  );
in
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];
  sops = {
    # This is pre-populated by the host sops module
    age.keyFile = "${homeDirectory}/.config/sops/age/keys.txt";

    defaultSopsFile = "${sopsFolder}/${config.hostSpec.hostName}.yaml";
    validateSopsFiles = false;

    # Linux: Exists in $XDG_RUNTIME_DIR/id_dade
    # Darwin: Exists in $(getconf DARWIN_USER_TEMP_DIR)
    #   ex: /var/folders/pp/t8_sr4ln0qv5879cp3trt1b00000gn/T/id_dade
    secrets = {
      "keys/git-crypt" = {
        sopsFile = "${sopsFolder}/shared.yaml";
      };

      "passwords/netrc" = {
        sopsFile = "${sopsFolder}/shared.yaml";
      };
      # formatted as extra-access-tokens = github.com=<PAT token>
      "tokens/nix-access-tokens" = {
        sopsFile = "${sopsFolder}/shared.yaml";
      };
    }
    # // lib.optionalAttrs config.hostSpec.isDevelopment {
    #   "tokens/openai" = {
    #     sopsFile = "${sopsFolder}/shared.yaml";
    #     path = "${homeDirectory}/.config/openai/token";
    #   };
    # }
    // lib.optionalAttrs config.hostSpec.isWork {
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
