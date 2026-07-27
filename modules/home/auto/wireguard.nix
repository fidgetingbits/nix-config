{
  lib,
  pkgs,
  osConfig,
  namespace,
  ...
}:
let
  wg-peer-names = pkgs.writeShellApplication {
    name = "wg";
    runtimeInputs = lib.attrValues {
      inherit (pkgs) wireguard-tools jq;
    };
    text =
      #bash
      ''
        if [[ "$#" -gt 0 && "$1" != "show" ]]; then
          command wg "$@"
          return
        fi

        MAP_FILE="/etc/wireguard/peer-names.json"
        _wg_show_peer_names() {
          if [[ ! -f "$MAP_FILE" ]]; then
            while IFS= read -r line; do
              echo "$line"
            done
            return
          fi

          while IFS= read -r line; do
            # Match 1: Full 'wg show' line format -> "peer: <key>"
            if [[ "$line" =~ ^([[:space:]]*)peer:[[:space:]]+([A-Za-z0-9+/=]{44})$ ]]; then
              echo "$line"
              key="''${BASH_REMATCH[2]}"
              name=$(jq -r --arg k "$key" '.[$k] // empty' "$MAP_FILE")
              [[ -n "$name" ]] && echo "  name: $name"
            # Match 2: 'wg show <if> peers' raw key output -> "<key>"
            elif [[ "$line" =~ ^[A-Za-z0-9+/=]{44}$ ]]; then
              local key="$line"
              name=$(jq -r --arg k "$key" '.[$k] // empty' "$MAP_FILE")
              if [[ -n "$name" ]]; then
                printf "%s\t(%s)\n" "$key" "$name"
              else
                echo "$key"
              fi
            else
              echo "$line"
            fi
          done
        }

        command wg "$@" | _wg_show_peer_names
      '';
  };
in
{
  config = lib.mkIf osConfig.${namespace}.wireguard.enable {
    home.packages = [
      (lib.hiPrio wg-peer-names)
    ];
  };
}
