{ pkgs, ... }:
{
  imports = [
    common/core
    common/core/nixos.nix

    common/optional/helper-scripts
    common/optional/sops.nix
    common/optional/xdg.nix
    common/optional/gpg.nix
    common/optional/atuin.nix
  ];

  home.packages = builtins.attrValues {
    inherit (pkgs)
      screen # Needed for serial console attached to server
      ;
  };

  systemd.user.startServices = "sd-switch";
}
