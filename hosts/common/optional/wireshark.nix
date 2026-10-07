{ config, pkgs, ... }:
{

  boot.kernelModules = [ "usbmon" ];

  programs.wireshark = {
    enable = true;
    package = pkgs.unstable.wireshark;
    dumpcap.enable = true;
    usbmon.enable = true;
  };

  users.users.${config.hostSpec.primaryUsername} = {
    extraGroups = [ "wireshark" ];
  };

}
