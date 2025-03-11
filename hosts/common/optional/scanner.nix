{ config, pkgs, ... }:
{
  hardware.sane.enable = true; # enables support for SANE scanners
  services.udev.packages = [ pkgs.sane-airscan ];
  services.ipp-usb.enable = true;
  hardware.sane.extraBackends = [ pkgs.sane-airscan ];
  users.users.${config.hostSpec.username}.extraGroups = [
    "scanner"
    "lp"
  ];
}
