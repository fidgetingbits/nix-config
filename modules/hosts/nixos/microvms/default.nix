# WIP module for setting up microvms, currently geared towards agents
# but slowly migrating towards being more generic
#
# Inspiration from:
# https://github.com/jasonodoom/nixos-configs/blob/17b43a1/framework-desktop/modules/ai-microvms.nix
# https://github.com/FintanH/fintos/blob/67dd2c/microvm/base.nix

{
  config,
  pkgs,
  lib,
  inputs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.microvms;

  user = config.hostSpec.primaryUsername;

  # Base directory for:
  # 1) data shared with only this microvm
  # 2) data shared across microvms
  sharedDir = "/home/${user}/dev/ai/";

  vm-lan = config.hostSpec.networking.subnets.nlan;

  # Make a microvm based on a common set of hosts/home files, using a
  # directory heirarchy that mirrors
  mkMicrovm = name: mvm: {
    # NOTE: Must add lib here to inject lib.custom
    specialArgs = {
      inherit inputs lib;
      namespace = "vm-${name}";
      vmOpts = {
        inherit
          name
          mvm
          user
          vm-lan
          ;
        sharedDir = sharedDir;
      };
    };
    config = lib.mkMerge [
      (
        { lib, ... }:
        {
          imports = lib.flatten [
            (lib.custom.relativeToRoot "microvms/hosts/common/core/")
            # Any extra settings for the host running the microvm
            mvm.extraMicrovmImports
          ];
        }
      )
    ];
  };
in
{
  options.${namespace} = {
    # NOTE: See ./vpn.nix for additional sub option
    microvms = {
      vms = lib.mkOption {
        type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything); # FIXME: make a type
        default = { };
        description = "List of microvms to setup";
      };
    };
  };

  imports = [
    inputs.microvm.nixosModules.host
    ./network.nix
    ./vpn.nix
  ];
  # FIXME: ugh. Should just have the defined microvm import and avoid this
  # ++ map (name: cfg.vms.${name}.extraImports) (lib.attrNames cfg.vms);

  config = lib.mkIf (lib.length (lib.attrNames cfg.vms) != 0) {
    # FIXME: Change "agents-shared" name, also add it to another scaffolding import
    systemd.tmpfiles.rules = [
      "d ${sharedDir}               0750 ${config.hostSpec.primaryUsername} users -"
      "d ${sharedDir}/shared        0750 ${config.hostSpec.primaryUsername} users -"
      "d ${sharedDir}/agents-shared 0750 1000 1000 -"
    ]
    ++ (
      cfg.vms
      |> lib.attrNames
      |> map (name: [
        "d ${sharedDir}/shared/${name}      0750 ${config.hostSpec.primaryUsername} users -"
        "d /run/microvm-secrets/        0750 root  kvm   -"
        "d /run/microvm-secrets/${name} 0750 root  kvm   -"
      ])
      |> lib.flatten
    );

    # IMPORTANT: It seems templates don't work. You can set path to point
    # into a folder mounted into the VM, but it will still symlink into
    # /run/secrets/rendered/ and that folder won't actually exist on the VM
    sops.secrets = (
      cfg.vms
      |> lib.attrNames
      |> lib.map (name: {
        "microvms/keys/ssh/${name}" = {
          owner = "root";
          group = "root";
          mode = "0400";
        };
      })
      |> lib.mergeAttrsList
    );

    # The secrets defined above won't be directly accessible in the virtiofs share
    # if placed with .path, because they are a symlink. So this service copies
    # the contents directly
    systemd.services.microvm-prepare-secrets = {
      description = "Stage SOPS secrets for microVM";
      wantedBy = [ "multi-user.target" ];
      after = [ "sops-nix.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      # systemd.tmpfiles.rules already handled dir creation
      script =
        cfg.vms
        |> lib.attrNames
        |> lib.map (name:
        # bash
        ''
          cp --remove-destination ${
            config.sops.secrets."microvms/keys/ssh/${name}".path
          } /run/microvm-secrets/${name}/ssh_host_ed25519_key
        '')
        |> lib.concatStringsSep "\n";
    };

    microvm = {
      vms = lib.mapAttrs mkMicrovm cfg.vms;
      autostart = lib.attrNames cfg.vms; # Ensures they boot with the host
    };

    environment = {
      systemPackages = [ inputs.microvm.packages.${pkgs.stdenv.hostPlatform.system}.microvm ];
    }
    // lib.optionalAttrs config.introdus.impermanence.enable {
      persistence.${config.hostSpec.persistFolder}.directories =
        lib.mkIf config.introdus.impermanence.enable
          [
            "/var/lib/microvms"
          ];
    };
  };
}
