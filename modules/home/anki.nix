{
  config,
  inputs,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.programs.anki;
  sopsFolder = (lib.toString inputs.nix-secrets) + "/sops";
  username = osConfig.hostSpec.primaryUsername;
  minimize-to-tray = pkgs.anki-utils.buildAnkiAddon (finalAttrs: {
    version = "2.1.0";
    pname = "minimize-to-tray";
    sourceRoot = "${finalAttrs.src.name}/src";
    src = pkgs.fetchFromGitHub {
      hash = "sha256-/87tH9nXyNSUqaI+bKhZ6vBqRA/OdloGTfmckFnRS3w=";
      owner = "simgunz";
      repo = "anki21-addons_minimize-to-tray";
      rev = finalAttrs.version;
      sparseCheckout = [ "src" ];
    };
  });
in
{
  config = lib.mkIf cfg.enable {
    sops.secrets = {
      "keys/anki" = {
        sopsFile = "${sopsFolder}/${osConfig.hostSpec.hostName}.yaml";
      };
    };
    programs.anki = {
      language = "en_US";
      answerKeys = [
        {
          ease = 1;
          key = "left";
        }
        {
          ease = 2;
          key = "up";
        }
        {
          ease = 3;
          key = "right";
        }
        {
          ease = 4;
          key = "down";
        }
      ];
      profiles.${username} = {
        default = true;
        sync = {
          autoSync = true;
          autoSyncMediaMinutes = 10;
          syncMedia = true;
          url = "https://anki.ooze.${osConfig.hostSpec.domain}";
          # usernameFile = config.sops.secrets."anki/username".path;
          inherit username;
          # NOTE: Log in once manually from anki with the custom server and it will throw
          # an error in the log details with the sync key, that you can then add to sops
          keyFile = config.sops.secrets."keys/anki".path;
        };
      };
      style = "native";
      theme = "followSystem";
      addons =
        (lib.attrValues {
          inherit (pkgs.ankiAddons) anki-connect;
          # bootstrapAddon
        })
        ++ [
          (minimize-to-tray.withConfig {
            config.hide_on_startup = "true";
          })
        ];
    };
  };
}
