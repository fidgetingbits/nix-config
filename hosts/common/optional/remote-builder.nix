# NOTE: Adding a new authorized key here will require the remote build machines
# to be rebuilt.
{ ... }:
let
  builderName = "builder";
in
{
  users.users.${builderName} = {
    isSystemUser = true; # Forces < 1000 UID, which is ignored by sddm
    uid = 800; # Try to force it below 1000 since isSystemUser isn't working
    useDefaultShell = true;
    group = builderName;
    description = "Remote Nix Build User";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJeSBvE5m1RYwCxrlfj/oeYZVcbmKTC0zeSotQepwurl onyx"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFYjvsmKfKgABXqfbOSooKbRt6f3fHyfIJFLuIkFSmyz ossa"
    ];
  };

  users.groups.${builderName} = { };
  nix.settings.trusted-users = [ builderName ];
}
