{
  config,
  lib,
  namespace,
  ...
}:
let
  networking = config.hostSpec.networking;
  subnets = networking.subnets;
  ports = networking.ports;
  llamaSwapPort = ports.tcp.llama-swap;
  picoSpecs = rec {
    vm-lan = subnets.p-lan;
    hostAuthorizedKeys = [
      subnets.o-lan.hosts.${config.networking.hostName}.sshPubKey
      subnets.o-lan.hosts."ossa".sshPubKey
    ];
    inherit (vm-lan.hosts.pico) ip;
    name = "pico";
    user = config.hostSpec.primaryUsername;
    mac = (lib.head vm-lan.hosts.pico.mac);
    sshPort = 22;
    sharedDir = config.${namespace}.microvms.sharedDir;
    allowedPorts = {
      # Expose local llama-swap for use by agents
      tcp = [
        llamaSwapPort
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
      _module.args.vmSpecs = picoSpecs;
      imports = [ (lib.custom.relativeToRoot "modules/hosts/nixos/microvms/agents.nix") ];
    }
  ];

  microvm.vms.pico = {
    specialArgs = {
      vmSpecs = picoSpecs;
    };
    config = {
      imports = [
        (lib.custom.relativeToRoot "microvms/hosts/common/optional/agents.nix")
      ];
      home-manager = {
        users.${picoSpecs.user} = {
          imports = [ ./home.nix ];
        };
      };
    };
  };

  ${namespace}.microvms = {
    vpn.enable = true;
  };
}
