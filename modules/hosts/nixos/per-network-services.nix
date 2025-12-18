# NOTE: Currently relies on networkmanager
{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.services.per-network-services;
in
{
  options.${namespace}.services.per-network-services = {
    enable = lib.mkOption {
      default = false;
      description = ''
        Enable per-network service management.

        Manage services which should be turned off and on depending on the network, as well as network mounts.
        For example, you might want to turn off a service when you're on a public network, or mount a network drive
        when you're at home.
      '';
    };
    mounts = lib.mkOption {
      default = [ ];
      description = ''
        List of mounts to enable or disable depending on the network
      '';
    };
    networkDevices = lib.mkOption {
      default = [ ];
      description = ''
        List of network devices to monitor
      '';
    };
    trustedNetworks = lib.mkOption {
      default = [ ];
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      description = ''
        List of trusted networks defining expected domain, mac address, interface, etc
      '';
    };
    trustedNetworkServices = lib.mkOption {
      default = [ ];
      description = ''
        Services to enable when on a trusted network (eg: syncthing)
      '';
    };
    untrustedNetworkServices = lib.mkOption {
      default = [ ];
      description = ''
        Services to enable when on an untrusted network (eg: VPN)
      '';
    };
    trustedNetworkMounts = lib.mkOption {
      default = [ ];
      description = ''
        Mounts to enable on trusted network. Currently must have a corresponding /etc/fstab entry
      '';
    };
    debug = lib.mkOption {
      default = false;
      description = ''
        Enable set -x debugging in dispatcher script
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    let
      toBashArray = list: list |> map (x: "\"${x}\"") |> lib.concatStringsSep " ";
      generateTrustedNetworkArray =
        cfg.trustedNetworks
        |> lib.imap0 (
          index: set: ''
            declare -A trusted_network_${toString index}
            trusted_network_${toString index}[type]="${set.type}"
            trusted_network_${toString index}[ssid]="${if set ? ssid then set.ssid else ""}"
            trusted_network_${toString index}[mac]="${set.mac}"
            trusted_network_${toString index}[gateway]="${set.gateway}"
          ''
        )
        |> lib.concatStringsSep "\n";

      trustedNetworkCheck =
        fieldOne: fieldTwo:
        cfg.trustedNetworks
        |> lib.imap0 (
          index: _:
          let
            i = toString index;
          in
          ''
            if [ "''$${lib.toUpper fieldOne}" = "''${trusted_network_${i}[${fieldOne}]}" ] && \
               [ "''$${lib.toUpper fieldTwo}" = "''${trusted_network_${i}[${fieldTwo}]}" ];
            then
              return 0
            fi
          ''
        )
        |> lib.concatStringsSep "\n";

      # FIXME: Harden firewall rules, in case service going down fails or whatever
      dispatcherScript = pkgs.writeShellApplication {
        name = "per-network-services.sh";
        runtimeInputs = lib.attrValues {
          inherit (pkgs)
            networkmanager
            gnugrep
            coreutils
            gnused
            libnotify
            ;
        };
        text =
          # bash
          ''
            ${if cfg.debug then "set -x" else ""}
            IFACE=$1
            if [ -z "$IFACE" ]; then
              exit 0
            fi
            ACTION=$2

            MONITORED_INTERFACES=(${toBashArray cfg.networkDevices});
            TRUSTED_SERVICES=(${toBashArray cfg.trustedNetworkServices});
            UNTRUSTED_SERVICES=(${toBashArray cfg.untrustedNetworkServices});
            TRUSTED_NETWORK_MOUNTS=(${toBashArray cfg.trustedNetworkMounts});

            ${generateTrustedNetworkArray}

            function logmsg() {
              logger -t per-network-services "$@"
            }

            function is_trusted_connection() {
              if [ "$CONNECTION_TYPE" = "802-11-wireless" ]; then
                # yes:foo -> foo
                SSID=$(nmcli -t -f active,ssid dev wifi | grep -E '^yes' | cut -d: -f2)
                # yes:00\:11\:22\:33\:44\:55 -> 00:11:22:33:44:55
                MAC=$(nmcli -t -f active,bssid dev wifi | grep -E '^yes' | cut -d: -f2- | sed -e 's/\\:/:/g')
                ${trustedNetworkCheck "ssid" "mac"}
              elif [ "$CONN_TYPE" = "802-3-ethernet" ]; then
                # default via 192.168.1.1 dev wlo1 proto dhcp src 192.168.1.2 metric 600 -> 192.168.1.1
                GATEWAY=$(ip route | grep -m 1 default | awk '{print $3} ')
                # 192.168.1.1 dev wlo1 lladdr 00:11:22:33:44:55 REACHABLE  -> 00:11:22:33:44:55
                MAC=$(ip neigh | grep "$GATEWAY " | awk '{print $5}')
                ${trustedNetworkCheck "gateway" "mac"}
              fi
              return 1
            }

            function start_untrusted_network_services() {
              logmsg "Starting untrusted network services"
              for service in "''${UNTRUSTED_SERVICES[@]}"; do
                if ! systemctl is-active --quiet "$service"; then
                  logmsg "Starting $service"
                  systemctl start "$service"
                fi
              done
            }

            function stop_untrusted_network_services() {
              logmsg "Stopping untrusted network services"
              for service in "''${UNTRUSTED_SERVICES[@]}"; do
                if systemctl is-active --quiet "$service"; then
                  logmsg "Stopping $service"
                  systemctl stop "$service"
                fi
              done
            }

            function start_trusted_network_services() {
              logmsg "Starting trusted network services"
              for service in "''${TRUSTED_SERVICES[@]}"; do
                if ! systemctl is-active --quiet "$service"; then
                  logmsg "Starting $service"
                  systemctl start "$service"
                fi
              done
            }

            function stop_trusted_network_services() {
              logmsg "Stopping trusted network services"
              for service in "''${TRUSTED_SERVICES[@]}"; do
                # logger "Checking $service"
                if systemctl is-active --quiet "$service"; then
                  logmsg "Stopping $service"
                  systemctl stop "$service"
                fi
              done
            }

            # FIXME: This expects it must be in fstab, so should probably check if it's there and assert otherwise?
            function mount_trusted_network_mounts() {
              logmsg "Mounting trusted network mounts"
              for location in "''${TRUSTED_NETWORK_MOUNTS[@]}"; do
                if ! mount | grep -q "$location"; then
                  logmsg "Mounting $location"
                  mount "$location"
                fi
              done
            }

            function unmount_trusted_network_mounts() {
              logmsg "Unmounting trusted network mounts"
              for location in "''${TRUSTED_NETWORK_MOUNTS[@]}"; do
                if mount | grep -q "$location"; then
                  logmsg "Unmounting $location"
                  umount "$location" || logger "Trusted Network Change: Failed to unmount $location"
                fi
              done
            }

            STATE_DIR="/run/per-network-services"
            mkdir -p $STATE_DIR || true
            STATE_FILE="$STATE_DIR/trusted_interfaces_up"
            LOCK_FILE="$STATE_DIR/trusted_interfaces_up.lock"

            logmsg "Interface $IFACE $ACTION"
            logmsg "''${MONITORED_INTERFACES[@]}"
            for monitored in "''${MONITORED_INTERFACES[@]}"; do
              if [ "$IFACE" = "$monitored" ]; then
              (
                flock -x 200
                case $ACTION in
                  up)
                    # 05cf90e6-7086-3e5b-a42c-4d9b14eccd8c:wlo1 -> 05cf90e6-7086-3e5b-a42c-4d9b14eccd8c
                    CONN_UUID=$(nmcli -t -f UUID,DEVICE connection show --active | grep "$IFACE" | cut -d: -f1)
                    CONNECTION_TYPE=$(nmcli -t -f UUID,TYPE connection show | grep "$CONN_UUID" | cut -d: -f2)

                    if is_trusted_connection; then
                      count=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
                      if [ "$count" -eq 0 ]; then
                        stop_untrusted_network_services
                        start_trusted_network_services
                        mount_trusted_network_mounts
                      fi
                      echo $((count + 1)) > "$STATE_FILE"
                    else
                      #$notify-send "Connected to untrusted network"
                      start_untrusted_network_services
                      stop_trusted_network_services
                      unmount_trusted_network_mounts
                    fi
                    ;;
                  down)
                    # Only tear everything down if all trusted networks are down, as there may be more than one
                    count=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
                    if [ "$count" -gt 0 ]; then
                      echo $((count - 1)) > "$STATE_FILE"
                    fi
                    if [ $((count-1)) -eq 0 ]; then
                      unmount_trusted_network_mounts
                      stop_trusted_network_services
                    fi
                    ;;
                esac
              ) 200>$LOCK_FILE
              break
              fi
            done
          '';
      };
    in
    {
      networking.networkmanager.dispatcherScripts = [
        {
          type = "basic";
          source = dispatcherScript;
        }
      ];

      # Don't autostart services dynamically managed by the dispatcher
      systemd.services =
        lib.genAttrs (cfg.trustedNetworkServices ++ cfg.untrustedNetworkServices)
          (name: {
            wantedBy = lib.mkForce [ ];
          });
    }
  );
}
