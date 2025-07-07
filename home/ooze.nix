{ pkgs, lib, ... }:
{
  imports = (
    map lib.custom.relativeToRoot (
      [
        "home/common/core"
        "home/common/core/nixos.nix"
      ]
      ++
        # Optional common modules
        (map (f: "home/common/optional/${f}") [
          "helper-scripts"
          "sops.nix"
          "xdg.nix"
          "gpg.nix"
          "atuin.nix"
        ])
    )
  );

  home.packages = builtins.attrValues {
    inherit (pkgs)
      screen # Needed for serial console attached to server
      ;
  };

  systemd.user.startServices = "sd-switch";
}
