{
  config,
  lib,
  inputs,
  ...
}:
# Define the users.users.<username> attrset here ONLY
{
  isNormalUser = true;
  extraGroups =
    let
      ifTheyExist = groups: lib.filter (group: lib.hasAttr group config.users.groups) groups;
    in
    lib.flatten [
      "wheel"
      "plugdev"
      (ifTheyExist [
        "audio"
        "video"
        "docker"
        "git"
        "networkmanager"
      ])
    ];

  # Avatar used by login managers like SDDM (must be PNG)
  icon = "${inputs.nix-assets}/images/avatars/multi-arm.png";
}
