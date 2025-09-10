{ pkgs, ... }:
{
  # Read iphones (see also ifuse?) https://nixos.wiki/wiki/IOS
  services.usbmuxd = {
    enable = true;
    package = pkgs.usbmuxd2; # Failing to connect to iphone 15
  };
  environment.systemPackages = builtins.attrValues { inherit (pkgs) ifuse libimobiledevice; };
}
