{
  config,
  # pkgs,
  lib,
  # inputs,
  namespace,
  ...
}:

let
  hostAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBpB8D7hvlBLDbt936OljTdpNcT01pHYqnnZj5rpD+xF ossa"
  ];
  lan = config.hostSpec.networking.subnets.nlan;
in
{
  ${namespace}.microvms = {
    vms = {
      # Agent vm with tooling, internet access
      nano = {
        user = config.hostSpec.primaryUsername;
        inherit (lan.hosts.nano) ip;
        mac = (lib.head lan.hosts.nano.mac);
        sshPort = 22;
        inherit hostAuthorizedKeys;
        packages = [ ];
        extraConfig = { };
      };
    };
    vpn.enable = true;
  };

  # VMs running long agentic tasks shouldn't get restarted on rebuild
  # https://github.com/microvm-nix/microvm.nix/blob/6ad601df/nixos-modules/host/options.nix#L151
  # FIXME: Should integration this into the above somehow
  # microvms.vms.nano.restartIfChanged = lib.mkForce false;
}
