{
  lib,
  pkgs,
  osConfig,
  ...
}:
{
  imports = [ ../wlogout.nix ];
  home = {
    packages = lib.attrValues {
      inherit (pkgs.unstable)
        niri
        xwayland-satellite # xwayland support
        ;
    };
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

        # Per-host values

        # Generic
      in
      {
        ".config/niri/config.kdl".text = finalConfig;
        #".config/niri/config.kdl".source = ./config.kdl;
        #".config/niri/workspaces.kdl".source = ./workspaces.kdl;
        #".config/niri/inputs.kdl".source = ./inputs.kdl;
        #".config/niri/outputs.kdl".source = ./outputs.kdl;
        #".config/niri/binds.kdl".source = ./binds.kdl;
        #".config/niri/rules.kdl".source = ./rules.kdl;
      };
  };
}
