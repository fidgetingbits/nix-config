# This is the base config of all microvm's generated
# user, name and mvm are passed from the builder as special args
{
  # config,
  # pkgs,
  lib,
  inputs,
  namespace,
  vmOpts,
  ...
}:
let
  # We do this to keep the paths synced between dev box and microvm, this allows something
  # like nvim codecompanion to relay local paths to remote host
  # FIXME: We could fix having a shared username by just doing root path like /shared/xxx
  # vmUser = config.hostSpec.primaryUsername;
  inherit (vmOpts)
    name
    mvm
    user
    vm-lan
    ;
  aiDir = vmOpts.sharedDir; # FIXME: rename this
in
{
  imports = lib.flatten [
    inputs.microvm.nixosModules.microvm
    mvm.extraMicrovmImports
  ];
  networking.hostName = "${name}";

  ${namespace}.microvm = {
    inherit name;
    inherit (mvm)
      user
      packages
      sshPort
      hostAuthorizedKeys
      extraConfig # FIXME: Use this
      ;
  };

  # FIXME: Maybe want this configurable eventually
  microvm = {
    hypervisor = "qemu";
    vcpu = 2;
    mem = 4096;
    balloon = true;

    # IMPORTANT: This is needed if you want microvm cli command to work
    # when not defining microvms as stand-alone flake outputs
    systemSymlink = true;

    # Writable nix store overlay (tmpfs — ephemeral).
    writableStoreOverlay = "/nix/.rw-store";

    # Persistent volumes (stored in /var/lib/microvms/<name>/)
    volumes = [
      {
        mountPoint = "/var";
        image = "var.img";
        size = 102400; # 100 GB
      }
      {
        mountPoint = "/nix/.rw-store";
        image = "nix-store.img";
        size = 61440; # 60 GB for nix store
      }
      {
        mountPoint = "/home/${user}";
        image = "home.img";
        size = 102400; # 100 GB for home directory
      }
    ];

    # NOTE: The id is important as it correlates to the tap on the host-side.
    # If you change the tap id prefix, change the tap matching in
    # microvms/network.nix as well
    # FIXME: It should just be some option I guess
    interfaces = [
      {
        type = "tap";
        id = "vm-microvm-${name}"; # IMPORTANT: Before changing, read the comment above
        mac = mvm.mac;
      }
    ];

    shares = [
      # Host's /nix/store (avoids building a squashfs image)
      # FIXME: Blacklist some files if possible?
      # There is a wifi password in /nix/store on some systems due to initrd ssh unlock
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }

      # Development folder for agent-specific projects
      {
        source = "${aiDir}/shared/${name}";
        mountPoint = "/home/${user}/dev/ai/shared/${name}";
        tag = "agent-dev";
        proto = "virtiofs";
      }
      # Shared folder used across microvms
      {
        source = "${aiDir}/agents-shared";
        mountPoint = "/home/${user}/dev/ai/agents-shared";
        tag = "agent-share";
        proto = "virtiofs";
      }
      # Secrets exposed from host sops
      {
        tag = "microvm-secrets";
        source = "/run/microvm-secrets/${name}";
        mountPoint = "/run/secrets";
        proto = "virtiofs";
      }
    ];
  };

  networking.useNetworkd = true;
  networking.useDHCP = false;

  # FIXME: use dhcp? if the host is bridged through vpn, it will use
  # whatever is provided like the default VPN dns?
  systemd.network.networks."10-eth" = {
    matchConfig.MACAddress = mvm.mac;
    address = [ "${mvm.ip}/${toString vm-lan.prefixLength}" ];
    routes = [ { Gateway = vm-lan.gateway; } ];
    dns = [
      "1.1.1.1"
      "8.8.8.8"
    ];
  };
}
