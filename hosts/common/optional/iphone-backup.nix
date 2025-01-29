{ pkgs, ... }:
{
  # Read iphones (see also ifuse?) https://nixos.wiki/wiki/IOS
  services.usbmuxd.enable = true;
  environment.systemPackages = builtins.attrValues { inherit (pkgs) ifuse libimobiledevice; };
}
