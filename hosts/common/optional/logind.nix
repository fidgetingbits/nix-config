{ ... }:
{
  services.acpid.enable = true;
  services.logind = {
    settings.Login = {
      HandlePowerKey = "suspend";
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
    };
  };
}
