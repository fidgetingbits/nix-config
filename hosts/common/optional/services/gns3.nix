# https://github.com/johnrizzo1/nixalt/blob/1c654b8c01c4ae3a2c90c4e48f75b4a4af30979b/modules/nixos/virt/gns3.nix#L17
{ config, pkgs, ... }:
{

  environment.systemPackages = builtins.attrValues {
    inherit (pkgs)
      gns3-gui
      gns3-server
      ubridge
      dynamips
      ;
  };

  # Is required for GNS3 to work. The GNS3 path to ubridge will have to be manually updated to /run/wrappers/bin/ubridge
  security.wrappers.ubridge = {
    source = "${pkgs.ubridge}/bin/ubridge";
    capabilities = "cap_net_admin,cap_net_raw=ep";
    owner = config.hostSpec.username;
    group = config.users.users.${config.hostSpec.username}.group;
    permissions = "u+rx,g+x";
  };

  # For now we run the built in server via gns3-gui
  # services.gns3-server = {
  #   enable = true;
  #   vpcs.enable = true;
  #   ubridge.enable = true;
  #   dynamips.enable = true;
  #   auth = {
  #     enable = false;
  #     user = "gns3";
  #     # passwordFile = config.sops.secrets."GNS3/password".path;
  #   };
  #   settings = {
  #     Server = {
  #       host = "127.0.0.1";
  #       port = 3080;
  #     };
  #   };
  # };
  # networking.firewall.allowedTCPPorts = [ 3080 ];
}
