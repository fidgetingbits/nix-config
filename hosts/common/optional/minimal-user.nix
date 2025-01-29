{ config, ... }:
{

  # Set a temp password for use by minimal builds like installer and iso
  users.users.${config.hostSpec.username} = {
    isNormalUser = true;
    hashedPassword = "$y$j9T$nBiwaZW8rasE2bXlpOkp2.$Zi86vOjw3b72K1pgodebfGu8JzK0HJtUTtHAUP7zHp4";
    extraGroups = [ "wheel" ];
  };
}
