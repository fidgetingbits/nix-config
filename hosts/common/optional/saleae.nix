{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    pulseview
    sigrok-cli
  ];
  services.udev.extraRules = ''
    ATTRS{idProduct}=="3881", ATTRS{idVendor}=="0925", MODE="660", GROUP="plugdev" SYMLINK+="saleae"
  '';
  users.extraUsers.${config.hostSpec.username}.extraGroups = [
    "plugdev"
  ];
  users.extraGroups = {
    plugdev = { };
  };
}
