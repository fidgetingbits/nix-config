{
  inputs,
  config,
  lib,
  ...
}:
{
  # NOTE: Some folders are handled in hosts/common/core/nixos.nix via xdg user dirs
  home.file =
    {
      # Avatar used by login managers like SDDM (must be PNG)
      ".face.icon".source = "${inputs.nix-assets}/images/avatars/multi-arm.png";
    }
    # Create some empty place holder folders no matter what
    // lib.mergeAttrsList (
      lib.map (path: { "${path}/.keep".text = "# Managed by Home Manager"; }) (
        [
          "dev"
          "mount"
          "images/screenshots"
          "public/source"
        ]
        ++ lib.optional config.hostSpec.isWork "work"
      )
    );

  home.activation.setupHomeLinks = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    if [ ! -n ${config.home.homeDirectory}/source ]; then
      ln -sf ${config.home.homeDirectory}/dev ${config.home.homeDirectory}/source
    fi
  '';
}
