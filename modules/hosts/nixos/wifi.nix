# Module to manage sets of wifi access points.
#
# This file loosely uses the term WLAN to refer to a set of access point names. In
# some cases this will be an actual set of Access Points on teh same Wireless
# LAN, however it is also used as a catchall for unrelated access points, like
# in the roaming case, which would be the set of all untrusted access points
# that a laptop might connect to.
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
let
  sopsFolder = (builtins.toString inputs.nix-secrets) + "/sops";
  cfg = config.wifi;

  # Return a list of all Access Point (AP) names from the given WLAN secret file
  readAPNames =
    file:
    pkgs.runCommand "${getWLAN file}-ap-names.txt" { } ''
      ${pkgs.yq}/bin/yq -r '.wifi | keys[]' ${sopsFolder}/${file}> "$out"
    ''
    |> builtins.readFile
    |> lib.splitString "\n";

  # The WLAN name 'foo' part of a file name such as 'wifi.foo.yaml'
  getWLAN = f: lib.elemAt (lib.splitString "." f) 1;
  isWLANUsed = f: lib.elem (getWLAN f) cfg.wlans;

  # Return a list of all WLAN secret files applicable to the system
  wifiSecretFiles =
    builtins.readDir sopsFolder
    |> lib.attrNames
    |> lib.filter (name: builtins.match "wifi\..*\.yaml" name != null)
    |> lib.filter (name: config.hostSpec.isRoaming || (isWLANUsed name));

  # Create the nmconnection entry used by NetworkManager
  connectionEntry = wlan: name: {
    "wifi/${name}" = {
      sopsFile = "${sopsFolder}/wifi.${wlan}.yaml";
      owner = "root";
      group = "root";
      mode = "0600";
      path = "/etc/NetworkManager/system-connections/${name}.nmconnection";
    };
  };

  # Generate NetworkManager nmconnection files for all applicable WLANs
  genWifiConnections =
    wifiSecretFiles
    |> map (
      file:
      readAPNames file
      # FIXME: Would be nice if we just never had empty names
      |> lib.filter (name: name != "")
      |> map (name: connectionEntry (getWLAN file) name)
    )
    |> builtins.concatLists
    |> lib.mergeAttrsList;

in
{
  options = {
    wifi = {
      wlans = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "home"
          "work"
        ];
        description = ''
          The set of WLANs the system will have configured for NetworkManager use

                Set 'config.hostSpec.isRoaming = true;' to use all

                An age key will need to be configured for every WLAN's wifi.*.yaml secret file in nix-secrets'';
      };
      disableWhenWired = lib.mkOption {
        type = lib.types.bool;
        default = false;
        example = true;
        description = "";
      };
    };
  };

  config = lib.mkIf config.hostSpec.wifi {
    # Wifi networks are broken into categories. We add the connections from the given
    # category, but also if the system isRoaming, then we add all connections from all
    # categories.
    sops.secrets = genWifiConnections;

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
