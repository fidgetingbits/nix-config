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
in
{
  imports = [ ../wlogout.nix ];
  home = {
    packages =
      lib.attrValues {
        inherit (pkgs.unstable)
          niri
          xwayland-satellite # xwayland support
          ;
      }
      ++ [ spawn-noctalia-settings ];
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
