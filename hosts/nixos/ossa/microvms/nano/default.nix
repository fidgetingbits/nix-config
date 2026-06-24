{
  config,
  lib,
  namespace,
  ...
}:
let
  networking = config.hostSpec.networking;
  subnets = networking.subnets;
  nanoSpecs = rec {
    vm-lan = subnets.nlan;
    hostAuthorizedKeys = [
      subnets.olan.hosts.${config.networking.hostName}.sshPubKey
    ];
    inherit (vm-lan.hosts.nano) ip;
    name = "nano";
    user = config.hostSpec.primaryUsername;
    mac = (lib.head vm-lan.hosts.nano.mac);
    sshPort = 22;
    sharedDir = config.${namespace}.microvms.sharedDir;
    allowedPorts = {
      # Expose local llama-swap for use by agents
      tcp = [ networking.ports.tcp.llama-swap ];
    };
  };
in
{
  imports = [
    # Anonymous submodule to allow us to specify an isolated vmSpecs
    {
      _module.args.vmSpecs = nanoSpecs;
      imports = [ (lib.custom.relativeToRoot "modules/hosts/nixos/microvms/agents.nix") ];
    }
  ];

  microvm.vms.nano = {
    specialArgs = {
      vmSpecs = nanoSpecs;
    };
    config = {
      imports = [
        (lib.custom.relativeToRoot "microvms/hosts/common/optional/agents.nix")
      ];
      home-manager = {
        # FIXME(microvms): This would need to change if we want multiple users
        users.${nanoSpecs.user} = {
          imports = [ ./home.nix ];
        };
      };
    };
  };

  ${namespace}.microvms = {
    vpn.enable = true;
  };
}
