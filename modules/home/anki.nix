{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.anki;
in
{
  config = lib.mkIf cfg.enable {
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
      profiles."User 1" = {
        default = true;
        sync = {
          autoSync = true;
          autoSyncMediaMinutes = 10;
          syncMedia = true;
          url = "https://anki.ooze.${osConfig.hostSpec.domain}";
          # usernameFile = config.sops.secrets."anki/username".path;
          username = osConfig.hostSpec.primaryUsername;
          # keyFile = config.sops.secrets."anki/key".path;
        };
      };
      style = "native";
      theme = "followSystem";
      addons = lib.attrValues {
        inherit (pkgs.ankiAddons) anki-connect;
        # bootstrapAddon
      };
    };
  };
}
