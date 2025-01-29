{ inputs, pkgs, ... }:
{
  imports = [
    inputs.mac-app-util.homeManagerModules.default
    common/core
    common/core/darwin.nix

    common/optional/ssh.nix
    common/optional/vscode.nix
    common/optional/sops.nix
    common/optional/development
    common/optional/helper-scripts
    common/optional/kitty.nix
    common/optional/wezterm.nix
    common/optional/media.nix
    common/optional/networking/syncthing.nix
    common/optional/atuin.nix
    common/optional/remmina.nix
  ];

  settings.work.enable = true;

  home.packages = builtins.attrValues {
    inherit (pkgs)
      # darwin-specific stuff
      duti # default app handler for macos
      raycast
      ;
  };
}
