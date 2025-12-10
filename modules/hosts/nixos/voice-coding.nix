{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.voiceCoding;
in
{
  imports = [ inputs.talon-nix.nixosModules.talon ];
  options.voiceCoding = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.hostSpec.voiceCoding;
      description = "Enable voice-coding features";
    };
  };
  config = lib.mkIf cfg.enable {
    services.joycond.enable = true;
    programs.talon.enable = true;

    # Rules for Tobii Eye Tracker for use with talon
    # IMPORTANT: These will go in 99-local.rules which is TOO LATE for uaccess to trigger. See
    # https://github.com/NixOS/nixpkgs/issues/210856 and
    # https://github.com/systemd/systemd/issues/4288#issuecomment-348166161
    # The original rules were 10-talon.rules, which are earlier enough, which the talon package actually uses...
    services.udev.packages = [
      (pkgs.writeTextFile {
        name = "tobii-udev-rules";
        text = ''
          SUBSYSTEM=="usb", ATTRS{idVendor}=="2104", ATTRS{idProduct}=="0127", TAG+="uaccess"
          SUBSYSTEM=="usb", ATTRS{idVendor}=="2104", ATTRS{idProduct}=="0118", TAG+="uaccess"
          SUBSYSTEM=="usb", ATTRS{idVendor}=="2104", ATTRS{idProduct}=="0106", TAG+="uaccess"
          SUBSYSTEM=="usb", ATTRS{idVendor}=="2104", ATTRS{idProduct}=="0128", TAG+="uaccess"
          SUBSYSTEM=="usb", ATTRS{idVendor}=="2104", ATTRS{idProduct}=="010a", TAG+="uaccess"
          SUBSYSTEM=="usb", ATTRS{idVendor}=="2104", ATTRS{idProduct}=="0102", TAG+="uaccess"
          SUBSYSTEM=="usb", ATTRS{idVendor}=="2104", ATTRS{idProduct}=="0313", TAG+="uaccess"
          SUBSYSTEM=="usb", ATTRS{idVendor}=="2104", ATTRS{idProduct}=="0318", TAG+="uaccess"
        '';
        destination = "/etc/udev/rules.d/10-tobii.rules";
      })
    ];

    environment.systemPackages = [
      pkgs.v4l-utils # for controlling the camera
    ];
  };

}
