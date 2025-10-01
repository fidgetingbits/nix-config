{ ... }:
{
  services.acpid.enable = true;
  services.logind = {
    powerKey = "suspend";
    lidSwitch = "suspend";
    extraConfig = ''
      HandleLidSwitchExternalPower=suspend
    '';
  };
}
