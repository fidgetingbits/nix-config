{ lib, ... }:
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

          "ssh.nix"
          "gnome-terminal.nix"
        ])
    )
  );

}
