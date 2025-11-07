{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
# FIXME(wifi): Possibly add something like below to remove internal domain stuff when on external wifi
# https://github.com/linyinfeng/dotfiles/blob/main/nixos/profiles/networking/network-manager/default.nix

# FIXME(wifi): Auto connect VPN when on untrusted wifi network:
# https://github.com/Defelo/nixos/blob/main/system/networking.nix
let
  sopsFolder = (builtins.toString inputs.nix-secrets) + "/sops";
  cfg = config.wifi;
in
{
  options = {
    wifi.disableWhenWired = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = "";
    };
  };
  config = lib.mkIf config.hostSpec.wifi {
    sops.secrets =
      inputs.nix-secrets.networking.wifiNetworks
      |> map (name: {
        "wifi/${name}" = {
          sopsFile = "${sopsFolder}/wifi.yaml";
          owner = "root";
          group = "root";
          mode = "0600";
          path = "/etc/NetworkManager/system-connections/${name}.nmconnection";
        };
      })
      |> lib.attrsets.mergeAttrsList;

    networking.networkmanager.dispatcherScripts = lib.optional cfg.disableWhenWired [
      {
        type = "basic";

        source =
          pkgs.writeText "disable-wireless-when-wired" # sh
            ''
              IFACE=$1
              ACTION=$2
              nmcli=${pkgs.networkmanager}/bin/nmcli

              case ''${IFACE} in
                  eth*|en*)
                      case ''${ACTION} in
                          up)
                              logger "disabling wifi radio"
                              $nmcli radio wifi off
                              ;;
                          down)
                              logger "enabling wifi radio"
                              $nmcli radio wifi on
                              ;;
                      esac
                      ;;
              esac
            '';
      }
    ];
  };
}
