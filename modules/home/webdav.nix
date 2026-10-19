# Access to ooze webdav
# This should be made generic so it just generates something with some params...
# Or just adapt it to programs.rclone?
{
  lib,
  inputs,
  pkgs,
  osConfig,
  config,
  namespace,
  ...
}:
let
  mountPath = "%h/wiki";
  sopsFolder = (lib.toString inputs.nix-secrets) + "/sops";
  cfg = config.${namespace}.rclone.wiki;
in
{
  options.${namespace}.rclone.wiki = {
    enable = lib.mkEnableOption "Wiki webdav mount on ooze";
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."passwords/webdav-ooze" = {
      sopsFile = "${sopsFolder}/${osConfig.hostSpec.hostName}.yaml";
    };

    sops.templates."rclone-webdav.conf".content = ''
      [wiki]
        type = webdav
        url = https://webdav.ooze.${osConfig.hostSpec.domain}/
        vendor = other
        user = webdav
        pass = ${config.sops.placeholder."passwords/webdav-ooze"}
    '';

    systemd.user.services.rclone-wiki-mount = {
      Service = {
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${mountPath}";
        ExecStart = ''
          ${pkgs.rclone}/bin/rclone mount wiki: ${mountPath} \
            --config ${config.sops.templates."rclone-webdav.conf".path} \
            --vfs-cache-mode full \
            --dir-cache-time 10m \
            --timeout 1m \
            --retries 10 \
            --allow-other
        '';
        ExecStop = "${pkgs.fuse}/bin/fusermount -u ${mountPath}";
        Restart = "on-failure";
        RestartSec = "10s";
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
