{ lib, ... }:
{
  introdus.system.initrd-wifi = {
    enable = true;
    interface = "wlp191s0";
    drivers = [
      "mt7925e"
    ];
    configFile = lib.custom.relativeToRoot "secrets/wpa_supplicant-olan.conf";
  };
}
