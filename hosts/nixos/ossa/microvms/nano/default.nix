{
  config,
  lib,
  namespace,
  ...
}:
let
  networking = config.hostSpec.networking;
  subnets = networking.subnets;
  olan = subnets.o-lan;
  nanoSpecs = rec {
    vm-lan = subnets.n-lan;
    hostAuthorizedKeys = [
      olan.hosts.${config.networking.hostName}.sshPubKey
    ];
    inherit (vm-lan.hosts.nano) ip;
    name = "nano";
    user = config.hostSpec.primaryUsername;
    mac = (lib.head vm-lan.hosts.nano.mac);
    sshPort = 22;
    sharedDir = config.${namespace}.microvms.sharedDir;
    allowedPorts = {
      # Expose local llama-swap for use by agents
      tcp = [
        # llamaSwapPort
      ];
    };
    # Some service stuff needs synced ports, so we need to expose it
    ports = config.hostSpec.networking.ports;
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

  ${namespace}.microvms = {
    vpn.enable = true;
  };

  # This needs to be injected because for now we manually forward a port
  # to oedo, so it needs to not route it over vm-vpn. Priority must be below
  # the vm-vpn entry in modules/hosts/nixos/microvms/network.nix
  # FIXME: This needs to keep in sync with the id in the file above, so could use an option
  systemd.network.networks."20-${config.${namespace}.microvms.vmBridge}" = {
    routingPolicyRules = [
      {
        From = config.${namespace}.microvms.vmLan.cidr;
        To = olan.cidr;
        Table = "main";
        Priority = 998;
      }
    ];
  };

  # NOTE: Below this line is the config of the VM itself
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
}
