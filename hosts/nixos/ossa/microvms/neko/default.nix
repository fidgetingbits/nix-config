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
  vmSpecs = rec {
    description = "Agent runner without internet";
    vm-lan = subnets.n-lan;
    hostAuthorizedKeys = [
      olan.hosts.${config.networking.hostName}.sshPubKey
    ];
    inherit (vm-lan.hosts.neko) ip;
    name = "neko";
    user = config.hostSpec.primaryUsername;
    mac = (lib.head vm-lan.hosts.neko.mac);
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
    vpn = false;
  };
in
{
  imports = [
    # Anonymous submodule to allow us to specify an isolated vmSpecs
    (
      args:
      import (lib.custom.relativeToRoot "modules/hosts/nixos/microvms/agents.nix") (
        args
        // {
          inherit vmSpecs;
        }
      )
    )
  ];

  # NOTE: Below this line is the config of the VM itself
  microvm.vms.neko = {
    specialArgs = {
      inherit vmSpecs;
    };
    config = {
      imports = [
        (lib.custom.relativeToRoot "microvms/hosts/common/optional/agents.nix")
      ];
      home-manager = {
        # FIXME(microvms): This would need to change if we want multiple users
        users.${vmSpecs.user} = {
          imports = [ ./home.nix ];
        };
      };
      # FIXME: Should we auto-assign these?
      # Starts at 3 for guests, and need to be unique per vm. So we use their LAN address
      # https://www.man7.org/linux/man-pages/man7/vsock.7.html
      microvm.vsock.cid = 4 + (lib.toInt (lib.custom.network.lastOctet vmSpecs.ip));
    };
  };
}
