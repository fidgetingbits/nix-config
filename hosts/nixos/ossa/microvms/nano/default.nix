{
  config,
  lib,
  namespace,
  ...
}:
let
  nanoOpts = rec {
    vm-lan = config.hostSpec.networking.subnets.nlan;
    # FIXME(microvms): This could be some hostSpec level entry for like microvm key, so we don't duplicate?
    hostAuthorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBpB8D7hvlBLDbt936OljTdpNcT01pHYqnnZj5rpD+xF ossa"
    ];
    inherit (vm-lan.hosts.nano) ip;
    name = "nano";
    user = config.hostSpec.primaryUsername;
    mac = (lib.head vm-lan.hosts.nano.mac);
    sshPort = 22;
    sharedDir = config.${namespace}.microvms.sharedDir;
  };
in
{
  microvm.vms.nano = {
    specialArgs = {
      vmOpts = nanoOpts;
    };
    config = {
      home-manager = {
        # FIXME(microvms): This would need to change if we want mutliple users
        users.${nanoOpts.user} = {
          imports = [ ./home.nix ];
        };
      };
    };
  };

  ${namespace}.microvms = {
    vpn.enable = true;
  };
}
