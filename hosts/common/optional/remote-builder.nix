{ ... }:
{
  users.users.builder = {
    isNormalUser = true;
    createHome = false;
    group = "builder";

    openssh.authorizedKeys.keyFiles = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJeSBvE5m1RYwCxrlfj/oeYZVcbmKTC0zeSotQepwurl onyx"
    ];
  };

  users.groups.builder = { };

  nix.settings.trusted-users = [ "builder" ];
}
