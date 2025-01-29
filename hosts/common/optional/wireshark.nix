{ config, ... }:
{
  programs.wireshark = {
    enable = true;
  };

  users.users.${config.hostSpec.username} = {
    extraGroups = [ "wireshark" ];
  };
}
