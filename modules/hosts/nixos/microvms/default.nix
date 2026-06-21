# WIP module for setting up microvms, currently geared towards agents
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

# Each agent runs in its own microvm for host-kernel and network
# isolation. The host reaches the guest sshd via a Linux bridge
# (virbr-ai); bash aliases on the host ssh into the VM
# and invoke the tool binary.

let
  cfg = config.${namespace}.microvms;

  sopsFolder = (lib.toString inputs.nix-secrets) + "/sops";
  user = config.hostSpec.primaryUsername;

  # Base directory for:
  # 1) data shared with only this microvm
  # 2) data shared across microvms
  aiDir = "/home/${user}/dev/ai/";

  vm-lan = config.hostSpec.networking.subnets.nlan;

  # FIXME: This should have the base config from a separate file
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
        sharedDir = aiDir;

      };
    };
    config = lib.mkMerge [
      (
        { lib, ... }:
        {
          imports = [ (lib.custom.relativeToRoot "microvms/hosts/common/core/") ];
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

  config = lib.mkIf (lib.length (lib.attrNames cfg.vms) != 0) {
    # FIXME: Should track the uid:gid for the microvm somewhere instead of hardcoding 1000?
    # I guess ideally we want it to match the UID on the host as well?
    # FIXME: vm-secrets part should loop over all vms
    systemd.tmpfiles.rules = [
      "d ${aiDir}               0750 ${config.hostSpec.primaryUsername} users -"
      "d ${aiDir}/shared        0750 ${config.hostSpec.primaryUsername} users -"
      "d ${aiDir}/agents-shared 0750 1000 1000 -"
    ]
    ++ (
      cfg.vms
      |> lib.attrNames
      |> map (name: [
        "d ${aiDir}/shared/${name}      0750 ${config.hostSpec.primaryUsername} users -"
        "d /run/microvm-secrets/        0750 root  kvm   -"
        "d /run/microvm-secrets/${name} 0750 root  kvm   -"
      ])
      |> lib.flatten
    );

    # IMPORTANT: It seems templates don't work. You can set path to point
    # into a folder mounted into the VM, but it will still symlink into
    # /run/secrets/rendered/ and that folder won't actually exist on the VM
    sops = {
      # FIXME: Move this to specific agent definitions somewhere else
      secrets = {
        "tokens/claude" = {
          sopsFile = "${sopsFolder}/agents.yaml";
          group = "kvm";
          mode = "0440";
        };
      }
      // (
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
    };

    # The secrets defined above won't be directly accessible in the virtiofs share
    # if placed with .path, because they are a symlink. So this service copies
    # the contents directly
    systemd.services.microvm-prepare-secrets = {
      description = "Stage SOPS secrets for microVM";
      wantedBy = [ "multi-user.target" ]; # FIXME: Is this best?
      after = [ "sops-nix.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      # systemd.tmpfiles.rules already handled dir creation
      # FIXME: non-key secrets should be system-specific
      script =
        cfg.vms
        |> lib.attrNames
        |> lib.map (name:
        # bash
        ''
          cp --remove-destination ${
            config.sops.secrets."microvms/keys/ssh/${name}".path
          } /run/microvm-secrets/${name}/ssh_host_ed25519_key
          # FIXME: Move this elsewhere
          cp --remove-destination ${
            config.sops.secrets."tokens/claude".path
          } /run/microvm-secrets/${name}/anthropic_api_key
          chgrp kvm /run/microvm-secrets/${name}/anthropic_api_key
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
