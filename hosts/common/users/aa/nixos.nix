{
  config,
  lib,
  ...
}:
let
  hostSpec = config.hostSpec;
  sopsHashedPasswordFile = lib.optionalString (
    !config.hostSpec.isMinimal
  ) config.sops.secrets."passwords/${hostSpec.username}".path;
in
# Define the users.users.<username> attrset here ONLY
{
  # Decrypt password to /run/secrets-for-users/ so it can be used to create the user
  isNormalUser = true;
  hashedPasswordFile = sopsHashedPasswordFile; # Blank if sops isn't working
  extraGroups =
    let
      ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
    in
    lib.flatten [
      "wheel"
      "plugdev"
      # FIXME: This causes infinite recursion after refactor
      (ifTheyExist [
        "audio"
        "video"
        "docker"
        "git"
        "networkmanager"
      ])
    ];
}
