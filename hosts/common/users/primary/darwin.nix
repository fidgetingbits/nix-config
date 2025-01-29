{ config, ... }:
{
  users.users.${config.hostSpec.username} = {
    home = "/Users/${config.hostSpec.username}";
  };
}
