# https://discourse.nixos.org/t/wireless-connection-within-initrd/38317/13
{
  config,
  lib,
  pkgs,
  ...
}:
# Some bug
# https://www.kernel.org/pub/linux/kernel/v6.x/ChangeLog-6.2.7
let
  cfg = config.system.initrd-wifi;
in
{
  options = {
    system.initrd-wifi = {
      enable = lib.mkEnableOption "Enable wifi in initrd";
      interface = lib.mkOption {
        type = lib.types.str;
        # FIXME: add something like this where per-host it's just already defined
        # default = config.networking.wifiInterface;
        example = "wlp193s0";
        description = "Wifi interface name shown by 'ip addr'";
      };
      drivers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        example = [ "iwlwifi" ];
        # see if there is some way to add them from facter lists or something?
        # default = ...;
        description = "Drivers needed for wifi hardware";
      };
      configFile = lib.mkOption {
        type = lib.types.path;
        example = "./foo";
        description = "wpa_supplicant.conf path containing ssid info. This should be encrypted in your repo";
      };
    };
  };
  config = lib.mkIf cfg.enable {

    boot.initrd =
      let
        confPath = "/etc/wpa_supplicant/wpa_supplicant-${cfg.interface}.conf";
      in
      {
        availableKernelModules = [
          # Generic wifi drivers
          "mac80211"
          "cfg80211"
          # Crypto drivers
          "ccm"
          "ctr"
          "cmac" # Needed for PMF to avoid: WPA: Failed to configure IGTK to the driver
        ]
        ++ cfg.drivers;

        secrets.${confPath} = cfg.configFile;

        systemd = {
          packages = [ pkgs.wpa_supplicant ];
          initrdBin = [ pkgs.wpa_supplicant ];
          targets.initrd.wants = [ "wpa_supplicant@${cfg.interface}.service" ];
          services."wpa_supplicant@".unitConfig.DefaultDependencies = false;

          network.enable = true;
          network.networks."10-wlan" = {
            matchConfig.Name = cfg.interface;
            networkConfig.DHCP = "yes";
          };
        };
      };
  };
}
