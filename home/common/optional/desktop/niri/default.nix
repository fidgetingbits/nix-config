{
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  spawn-noctalia-settings = pkgs.writeShellApplication {
    name = "spawn-noctalia-settings";
    runtimeInputs = lib.attrValues {
      inherit (pkgs)
        jq
        ;
    };
    text =
      # bash
      ''
          APP_ID="dev.noctalia.noctalia-qs"
          WIN_ID=$(niri msg --json windows | jq -r ".[] | select(.app_id == \"$APP_ID\") | .id" | head -n 1)
        if [ -n "$WIN_ID" ]; then
             niri msg action focus-window --id "$WIN_ID"
        else
             noctalia-shell ipc call settings open
        fi
      '';
  };
  spawn-nvim-scratchpad = pkgs.writeShellApplication {
    name = "spawn-nvim-scratchpad";
    runtimeInputs = lib.attrValues {
      inherit (pkgs) nirius;
    };
    text =
      # bash
      ''
        APP_ID="neovide-scratchpad"
        if ! niri msg --json windows | jq -e --arg app "$APP_ID" '.[] | select(.app_id == $app)' > /dev/null; then
            NEOVIDE_APP_ID="$APP_ID" nvim-neovide -- -c 'lua require([[resession]]).load([[nix]])' &

            # Poll for window creation (up to 2 seconds max)
            for _ in $(seq 1 20); do
                if niri msg --json windows | jq -e --arg app "$APP_ID" '.[] | select(.app_id == $app)' > /dev/null; then
                    break
                fi
                sleep 0.1
            done

            # WINDOW_ID=$(niri msg --json windows | jq -r --arg app "$APP_ID" '.[] | select(.app_id == $app) | .id' | head -n 1)
            # if [ -n "$WINDOW_ID" ]; then
            #     niri msg action center-window --id "$WINDOW_ID"
            # fi

            nirius scratchpad-toggle -a "$APP_ID"
        fi
      '';
  };
in
{
  home = {
    packages =
      lib.attrValues {
        inherit (pkgs.unstable)
          niri
          xwayland-satellite # xwayland support
          ;
      }
      ++ [
        spawn-noctalia-settings
        spawn-nvim-scratchpad
      ];
    file =
      let
        hostPath = "hosts/nixos/${osConfig.hostSpec.hostName}/niri";
        finalConfig =
          lib.flatten [
            ./inputs.kdl
            (map lib.custom.relativeToRoot [
              "${hostPath}/outputs.kdl"
              "${hostPath}/workspaces.kdl"
            ])
            ./binds.kdl
            ./rules.kdl
            ./config.kdl
            # (if osConfig.hostSpec.isMultiMonitor then ./multi-monitor-binds.kdl else ./single-monitor-binds.kdl)
          ]
          |> lib.concatMapStringsSep "\n" lib.readFile;

      in
      {
        ".config/niri/config.kdl".text = finalConfig;
        ".config/niri/animations/" = {
          source = ./animations;
          recursive = true;
        };
      };
  };
}
