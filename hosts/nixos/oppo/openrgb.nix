# FIXME: Likely make this a module or something
{ pkgs, ... }:
{
  services.udev.packages = [ pkgs.openrgb-with-all-plugins ];
  hardware.i2c.enable = true;
  services.hardware.openrgb = {
    enable = true;
    package = pkgs.openrgb-with-all-plugins;
    motherboard = "amd";
    server = {
      port = 6742;
    };
  };
  systemd.services.openrgb-pre-suspend = {
    description = "Set OpenRGB to off before suspend";
    wantedBy = [
      "halt.target"
      "sleep.target"
      "suspend.target"
    ];
    before = [
      "sleep.target"
      "suspend.target"
    ];
    partOf = [ "openrgb.service" ];
    requires = [ "openrgb.service" ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "20s";
      ExecStart = "${pkgs.openrgb}/bin/openrgb --mode off";
    };
  };
  systemd.services.openrgb-post-resume = {
    description = "Reload OpenRGB profile after resume";
    wantedBy = [
      "post-resume.target"
      "suspend.target"
    ];
    after = [
      "openrgb.service"
      "suspend.target"
    ];
    requires = [ "openrgb.service" ];
    partOf = [ "openrgb.service" ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "10s";
      ExecStart = "${pkgs.openrgb}/bin/openrgb -m static --color FFFFFF";
      # ExecStart = "${pkgs.openrgb}/bin/openrgb --profile ${./oppo.orp}";
    };
  };
}
