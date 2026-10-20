# Access to ooze webdav
# This should be made generic so it just generates something with some params...
{
  lib,
  inputs,
  osConfig,
  config,
  namespace,
  ...
}:
let
  mountPath = "%h/wiki";
  sopsFolder = (lib.toString inputs.nix-secrets) + "/sops";
  cfg = config.${namespace}.rclone.wiki;
  # FIXME: Make this an option
  server = "ooze";
in
{
  options.${namespace}.rclone.wiki = {
    enable = lib.mkEnableOption "Wiki webdav mount on ${server}";
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."passwords/webdav-${server}" = {
      sopsFile = "${sopsFolder}/${osConfig.hostSpec.hostName}.yaml";
    };

    programs.rclone = {
      enable = true;
      remotes.wiki = {
        config = {
          type = "webdav";
          url = "https://webdav.${server}.${osConfig.hostSpec.domain}/";
          vendor = "other";
          user = "webdav";
        };
        secrets = {
          pass = config.sops.secrets."passwords/webdav-${server}".path;
        };
        mounts."" = {
          enable = true;
          autoMount = true;
          mountPoint = mountPath;
          options = {
            vfs-cache-mode = "full";
            dir-cache-time = "10m";
            timeout = "1m";
            retries = 10;
            allow-other = true;
          };
        };
      };
    };
  };
}
