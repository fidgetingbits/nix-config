{
  config,
  lib,
  inputs,
  namespace,
  ...
}:

let
  hostAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBpB8D7hvlBLDbt936OljTdpNcT01pHYqnnZj5rpD+xF ossa"
  ];

  vm-lan = config.hostSpec.networking.subnets.nlan;
  nanoOpts = {
    inherit hostAuthorizedKeys vm-lan;
    inherit (vm-lan.hosts.nano) ip;
    name = "nano";
    user = config.hostSpec.primaryUsername;
    mac = (lib.head vm-lan.hosts.nano.mac);
    sshPort = 22;
    sharedDir = config.${namespace}.microvms.sharedDir;
  };

  mkMicrovm = name: auto: opts: cfg: {
    autostart = auto;
    # VMs running long agentic tasks shouldn't get restarted on rebuild
    # https://github.com/microvm-nix/microvm.nix/blob/6ad601df/nixos-modules/host/options.nix#L151
    # restartIfChanged = lib.mkForce false;

    specialArgs = {
      inherit inputs lib;
      namespace = "vm-${name}";
      vmOpts = opts;
    };
    config = lib.mkMerge [
      {
        imports = [
          (lib.custom.relativeToRoot "microvms/hosts/common/core/")
        ];
      }
      cfg
    ];
  };
in
{
  microvm.vms.nano = mkMicrovm "nano" true nanoOpts {
    imports = [ (lib.custom.relativeToRoot "microvms/hosts/common/optional/agents.nix") ];
  };

  # FIXME: Revisit how we want to do this since we direct access microvms.vm now
  # We should auto-generate some aspect of everything?
  ${namespace}.microvms = {
    vms.nano = nanoOpts;
    vpn.enable = true;
  };
}
