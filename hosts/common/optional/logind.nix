# https://github.com/asus-linux-drivers/asus-fliplock-driver
{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.libinput # debug events
    pkgs.acpid # debug acpi events
  ];
  services.acpid.enable = true;
  services.logind = {
    settings.Login = {
      HandlePowerKey = "suspend";
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
    };
  };
}
