{
  lib,
  config,
  inputs,
  ...
}:
{

  isNormalUser = true;
  extraGroups =
    let
      ifTheyExist = groups: lib.filter (group: lib.hasAttr group config.users.groups) groups;
    in
    lib.flatten [
      (ifTheyExist [
        "audio"
        "video"
      ])
    ];

  # Avatar used by login managers like SDDM (must be PNG)
  icon = "${inputs.nix-assets}/images/avatars/corgi-boba.png";
}
