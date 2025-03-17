{ config, pkgs, ... }:
{

  boot.kernelModules = [ "usbmon" ];
  services.udev.extraRules = ''
    SUBSYSTEM=="usbmon", GROUP="wireshark", MODE="640"
  '';

  environment.systemPackages = [
    pkgs.unstable.wireshark # 4.2.x is broken with latest QT
  ];

  users.users.${config.hostSpec.username} = {
    extraGroups = [ "wireshark" ];
  };

  users.extraGroups = {
    wireshark = { };
  };
}
