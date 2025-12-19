# Example ofo a network to add to trustedNetworks:
#  my-network = {
#    type = "wireless";
#    ssid = "my-ssid";
#    interface = "wlo1";
#    gateway = "192.168.1.1";
#    mac = "aa:bb:cc:dd:ee:ff";
#  };
{
  lib,
  inputs,
  namespace,
  secrets,
  ...
}:
{
  networking.networkmanager.enable = true;

  ${namespace} = {
    cifs-mounts = {
      enable = true;
      sopsFile = (builtins.toString inputs.nix-secrets) + "/sops/olan.yaml";
      mounts = [
        {
          name = "onus";
        }
        {
          name = "oath";
        }
      ];
    };
    services.per-network-services = {
      enable = true;
      debug = true; # FIXME(onyx): Remove this
      # FIXME: This should be synchronized with the code that renames it
      networkDevices = [ "wlo1" ];
      trustedNetworks = lib.flatten [
        secrets.networking.trusted.homeWifi
        secrets.networking.trusted.homeWired
      ];
    };
  };

  networking.granularFirewall.enable = true;
}
