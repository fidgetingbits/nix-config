{ lib, ... }:
{
  # FIXME: This duplicates from default, but is referenced explicitly by minimal while testing
  # could switch it to core.nix or something?
  introdus.system.initrd-wifi = {
    enable = true;
    interface = "wlp191s0";
    drivers = [
      "mt7925e"
    ];
    configFile = lib.custom.relativeToRoot "secrets/wpa_supplicant-olan.conf";
  };
}
