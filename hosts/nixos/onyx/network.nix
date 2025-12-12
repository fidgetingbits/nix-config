{
  #inputs,
  ...
}:
{

  networking.networkmanager.enable = true;

  # services.per-network-services =
  #   let
  #     # Define what trusted networks looks like for this system
  #     oryx = {
  #       type = "wireless";
  #       ssid = "oryx";
  #       interface = "wlo1";
  #       gateway = inputs.nix-secrets.networking.subnets.ogre.hosts.oryx.ip;
  #       mac = inputs.nix-secrets.networking.subnets.ogre.hosts.oryx.mac;
  #     };
  #     ogre = {
  #       type = "wired";
  #       domain = inputs.nix-secrets.domain;
  #       interface = "";
  #       gateway = inputs.nix-secrets.networking.subnets.ogre.hosts.ogre.ip;
  #       mac = inputs.nix-secrets.networking.subnets.ogre.hosts.ogre.mac;
  #     };
  #   in
  #   {
  #     enable = true;
  #     debug = true; # FIXME(onyx): Remove this
  #     # FIXME: This should be synchronized with the code that renames it
  #     networkDevices = [ "wlo1" ];
  #     trustedNetworks = [
  #       oryx
  #       ogre
  #     ];
  #   };

  networking.granularFirewall.enable = true;
}
