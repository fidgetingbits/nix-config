# Module to manage sets of wifi access points.
#
# This file loosely uses the term WLAN to refer to a set of access point names. In
# some cases this will be an actual set of Access Points on the same Wireless
# LAN, however it is also used as a catchall for unrelated access points, like
# in the roaming case, which would be the set of all untrusted access points
# that a laptop might connect to.
#
# Note that for now my approach is to drop an nmconnection entry into sops
# secrets and link the file, but something like ensureConnections or
# ensureProfiles would be better if I can use sops-nix to template in a way
# that both the connection names and passwords are hidden. The nmconnection
# approach is "easier" because I can manually connect with NetworkManager
# and then quickly copy the whole file (minus the interface) elsewhere.
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
  # NOTE: This uses IFD in order to read SOPS yaml keys
  readAPNames =
    file:
    pkgs.runCommand "${getWLAN file}-ap-names.txt" { } ''
      ${pkgs.yq}/bin/yq -r '.wifi | keys[]' ${sopsFolder}/${file}> "$out"
    ''
    |> lib.readFile
    |> lib.splitString "\n";

  # The WLAN name 'foo' part of a file name such as 'wifi.foo.yaml'
  getWLAN = f: lib.elemAt (lib.splitString "." f) 1;
  isWLANUsed = f: lib.elem (getWLAN f) cfg.wlans;

  allWLANFiles =
    builtins.readDir sopsFolder
    |> lib.attrNames
    |> lib.filter (name: lib.match "wifi\..*\.yaml" name != null);

  allWLANs = allWLANFiles |> map (file: getWLAN file);

  # Return a list of all WLAN secret files applicable to the system
  filteredWLANFiles = allWLANFiles |> lib.filter (name: cfg.roaming || (isWLANUsed name));

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
    filteredWLANFiles
    |> map (
      file:
      readAPNames file
      # nixfmt hack to not merge |> lines
      |> lib.filter (name: name != "")
      |> map (name: connectionEntry (getWLAN file) name)
    )
    |> lib.concatLists
    |> lib.mergeAttrsList;
in
{
  options = {
    wifi = {
      enable = lib.mkEnableOption (lib.mdDoc ''Wireless LAN Management'');
      roaming = lib.mkOption {
        type = lib.types.bool;
        default = false;
        example = true;
        description = "Indicates a host that moves between locations and should get all wifi networks configured. Using config.wifi.wlans is not required if this value is true.";
      };
      wlans = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "home"
          "work"
        ];
        description = ''
          The set of WLANs the system will have configured for NetworkManager use.

          Set 'config.wifi.roaming = true;' to use all.

          An age key will need to be configured for every WLAN's wifi.*.yaml secret file in nix-secrets.'';
      };
      disableWhenWired = lib.mkOption {
        type = lib.types.bool;
        default = false;
        example = true;
        description = "";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = genWifiConnections;

    # sops-nix won't clean up old nmconnection files, so this removes any dead links
    # from /etc/NetworkManager/system-connections/ that may be left over from wlan changes
    # or other testing
    system.activationScripts.dead-wifi-cleanup =
      let
        find = lib.getExe' pkgs.findutils "find";
        rm = lib.getExe' pkgs.coreutils "rm";
      in
      {
        deps = [ "setupSecrets" ]; # sops dependency
        text = "${find} -L . -name . -o -type d -prune -o -type l -exec ${rm} {} +";
      };

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
    assertions = [
      {
        assertion = (cfg.roaming || lib.length cfg.wlans != 0);
        message = "config.wifi.roaming must be true or config.wifi.wlans should be set to one of:\n  ${toString allWLANs}";
      }
    ];
  };
}
