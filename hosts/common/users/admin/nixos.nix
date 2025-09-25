{
  config,
  lib,
  ...
}:
# Define the users.users.<username> attrset here ONLY
{
  isNormalUser = true;
  extraGroups =
    let
      ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
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
}
