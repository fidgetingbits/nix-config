# WIP module for setting up ai-agent microvms
# Inspiration from:
# https://github.com/jasonodoom/nixos-configs/blob/17b43a1/framework-desktop/modules/ai-microvms.nix

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

  # FIXME: Rename this
  agents = cfg.vms;

  # FIXME: Rename this
  agent-lan = config.hostSpec.networking.subnets.agent-lan;
  # FIXME: Rename this
  agentsBridge = "vbr-agents";

  mkAgentVm = name: agent: {
    # NOTE: Must add lib here to inject lib.custom
    specialArgs = {
      inherit inputs lib;
      namespace = "vm-${name}";
    };
    config =
      {
        # config,
        # pkgs,
        lib,
        inputs,
        namespace,
        ...
      }:
      let
        # We do this to keep the paths synced between dev box and microvm, this allows something
        # like nvim codecompanion to relay local paths to remote host
        # FIXME: We could fix having a shared username by just doing root path like /shared/xxx
        vmUser = config.hostSpec.primaryUsername;
      in
      {
        imports = lib.flatten [
          inputs.microvm.nixosModules.microvm
          # FIXME: This should be supplied as an extra config of whoever is setting up the system
          ./ai-agent-config.nix
        ];

        networking.hostName = "${name}";

        ${namespace}.microvm = {
          inherit name;
          inherit (agent)
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
          # If you change vm-agent- prefix, change the tap matching as well
          # FIXME: It should just be some option I guess
          interfaces = [
            {
              type = "tap";
              id = "vm-agent-${name}"; # IMPORTANT: Before changing, read the comment above
              mac = agent.mac;
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
              mountPoint = "/home/${vmUser}/dev/ai/shared/${name}";
              tag = "agent-dev";
              proto = "virtiofs";
            }
            # Shared folder used across microvms
            {
              source = "${aiDir}/agents-shared";
              mountPoint = "/home/${vmUser}/dev/ai/agents-shared";
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

        # FIXME: Move this to network.nix
        networking.useNetworkd = true;
        networking.useDHCP = false;

        # FIXME: use dhcp? if the host is bridged through vpn, it will use
        # whatever is provided like the default VPN dns?
        systemd.network.networks."10-eth" = {
          matchConfig.MACAddress = agent.mac;
          address = [ "${agent.ip}/${toString agent-lan.prefixLength}" ];
          routes = [ { Gateway = agent-lan.gateway; } ];
          dns = [
            "1.1.1.1"
            "8.8.8.8"
          ];
        };
      };
  };
in
{
  options.${namespace} = {
    microvms = {
      vms = lib.mkOption {
        type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything); # FIXME: make a type
        default = { };
        description = "List of ai agent microvms to setup";
      };
    };
  };

  imports = [
    inputs.microvm.nixosModules.host
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
      agents
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
          sopsFile = "${sopsFolder}/ai-agents.yaml";
          group = "kvm";
          mode = "0440";
        };
      }
      // (
        agents
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
      script =
        agents
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

    ${namespace} = {
      agents-vpn.enable = true;
    };

    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };
    systemd.network = {
      enable = true;
      wait-online.enable = false;

      # Bridge device for agent microvms back to host
      netdevs."20-${agentsBridge}".netdevConfig = {
        Kind = "bridge";
        Name = agentsBridge;
      };

      networks."20-${agentsBridge}" = {
        matchConfig.Name = agentsBridge;
        addresses = [ { Address = "${agent-lan.gateway}/${toString agent-lan.prefixLength}"; } ];
        networkConfig.ConfigureWithoutCarrier = true;

        routingPolicyRules = [
          # Allow access between the guest and the host
          {
            From = agent-lan.cidr;
            To = agent-lan.cidr;
            Table = "main";
            Priority = 999;
          }
          # Route everything else over VPN
          {
            From = agent-lan.cidr;
            Table = 42; # wg-proton-agents table
            Priority = 1000;
          }
        ];
      };

      # Creates a tap between vbr-agents and all agent vms that follow the vm-*
      # naming pattern
      networks."21-${agentsBridge}-tap" = {
        matchConfig.Name = "vm-agent-*"; # NOTE: Corresponds to mkAgentVm func's microvms.interfaces
        networkConfig.Bridge = agentsBridge;
      };

    };

    # Outbound NAT only for packets going out the proton vpn
    # Allow established traffic for host -> microvm ssh session
    networking.nftables = {
      enable = true;

      # FIXME: make the agents-vpn name configurable
      ruleset = ''
        table inet agent_firewall {
              chain input {
                type filter hook input priority filter; policy accept;

                ct state established,related accept
                iifname "${agentsBridge}" drop
              }

              chain output {
               type filter hook output priority filter;
               oifname "${agentsBridge}" accept
              }

              chain forward {
                type filter hook forward priority filter; policy drop;

                # Allow established internet traffic back to the VM
                ct state established,related accept

                # Allow the VM to push outbound traffic specifically out the VPN interface
                iifname "${agentsBridge}" oifname "agents-vpn" accept
              }

              # 4. NAT FOR THE VPN CONTEXT
              chain postrouting {
                type nat hook postrouting priority filter; policy accept;
                oifname "agents-vpn" masquerade
              }
            }
      '';
    };

    microvm.vms = lib.mapAttrs mkAgentVm agents;
    microvm.autostart = lib.attrNames agents; # Ensures they boot with the host

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
