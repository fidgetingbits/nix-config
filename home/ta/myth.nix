{
  inputs,
  lib,
  ...
}:
{
  imports =
    (map lib.custom.relativeToRoot [
      "home/common/core"
      "home/common/core/nixos.nix"
    ])
    ++ [
      # FIXME: Some weirdness. importing in modules/home/common/auto-styling.nix breaks actually styled systems even if they aren't importing this elsewhere? But not importing it on myth breaks the conditional
      inputs.stylix.homeModules.stylix
    ];

  home.packages = lib.attrValues {

  };
  system.ssh-motd.enable = true;
}
