{ lib, config, ... }:
{
  isNormalUser = true;
  extraGroups =
    let
      ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
    in
    lib.flatten [
      (ifTheyExist [
        "audio"
        "video"
      ])
    ];
}
