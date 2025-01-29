{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:
let
  attic = pkgs.attic-client;
  attic_token = config.sops.secrets."tokens/attic-client".path;
  attic_server = "https://atticd.ooze.${config.hostSpec.domain}";
  sopsFolder = (builtins.toString inputs.nix-secrets) + "/sops";
in
{
  options = {
    attic-client = {
      cache-name = lib.mkOption {
        type = lib.types.str;
        default = "o-cache";
        description = "The name of the attic cache";
      };
    };
  };

  config = lib.mkIf config.hostSpec.useAtticCache {
    sops.secrets."tokens/attic-client" = {
      sopsFile = "${sopsFolder}/shared.yaml";
    };

    systemd.services.attic-watch-store = {
      description = "Attic client watch-store service";
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.writeShellScript "watch-store" ''
          #!/run/current-system/sw/bin/bash
          set -x
          ATTIC_TOKEN=$(cat ${attic_token})
          ${attic}/bin/attic login ${config.attic-client.cache-name} ${attic_server}  $ATTIC_TOKEN
          ${attic}/bin/attic watch-store ${config.attic-client.cache-name}
        ''}";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    services.per-network-services.trustedNetworkServices = [ "attic-watch-store" ];

  };
}
