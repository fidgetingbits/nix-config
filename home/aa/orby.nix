{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  imports = lib.flatten (
    [
      inputs.mac-app-util.homeManagerModules.default
    ]
    ++ (map lib.custom.relativeToRoot (
      [
        "home/common/core"
        "home/common/core/darwin.nix"
      ]
      ++
        # Optional common modules
        (map (f: "home/common/optional/${f}") [
          "ssh"
          "vscode"
          "sops.nix"
          "development"
          "helper-scripts"
          "kitty.nix"
          "wezterm.nix"
          "media.nix"
          "networking/syncthing.nix"
          "atuin.nix"
          "remmina.nix"
        ])
    ))
  );

  settings.work.enable = true;

  home.packages = builtins.attrValues {
    inherit (pkgs)
      # darwin-specific stuff
      duti # default app handler for macos
      raycast
      ;
  };
}
