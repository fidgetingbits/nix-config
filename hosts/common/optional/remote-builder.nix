{ ... }:
{
  users.users.remotebuild = {
    isNormalUser = true;
    createHome = false;
    group = "builder";

    openssh.authorizedKeys.keyFiles = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJeSBvE5m1RYwCxrlfj/oeYZVcbmKTC0zeSotQepwurl onyx"
    ];
  };

  users.groups.remotebuild = { };

  nix.settings.trusted-users = [ "builder" ];
}
