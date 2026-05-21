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
#
# State (OAuth tokens, config) lives in
# ~/.local/state/ai-agents/<name> and is virtiofs-shared into
# the guest as /home/agent. ~/code is shared read-write.

let
  cfg = config.${namespace}.ai-agents;

  user = config.hostSpec.primaryUsername;
  # FIXME: revisit this path as I don't think I want it here
  # If you change it see home/auto/ai-agents.nix too
  microvmState = "/home/${user}/.local/state/ai-agents";

  # Base directory for:
  # 1) data shared with only this microvm
  # 2) data shared across microvms
  sharedDir = "/home/${user}/microvm/shared";

  agents = cfg.vms;

  agent-lan = config.hostSpec.networking.subnets.agent-lan;
  agentsBridge = "vbr-agents";

  mkAgentVm = name: agent: {
    # FIXME: Required for microvm -l to work, but requires
    # the agents listed as outputs? Use our own mv aliases for now
    # flake = inputs.self;

    # NOTE: Must add lib here to inject lib.custom
    specialArgs = {
      inherit inputs lib;
      namespace = "agent-microvm";
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
        agentUser = "agent";
      in
      {
        imports = lib.flatten [
          inputs.microvm.nixosModules.microvm
          ./ai-agent-config.nix
        ];

        # FIXME: Setup the numtide llm-agent.nix stuff
        # nixpkgs.overlays = [ (import ../overlays/default.nix { inherit inputs; }) ];

        system.stateVersion = "25.11";
        networking.hostName = "ai-${name}";

        ${namespace}.microvm = {
          inherit name;
          inherit (agent)
            packages
            sshPort
            hostAuthorizedKeys
            extraConfig
            ;
        };

        # FIXME: Maybe want this configurable eventually
        microvm = {
          hypervisor = "qemu";
          vcpu = 2;
          mem = 4096;
          balloon = true;

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
            # Basic home directory where
            {
              source = "${microvmState}/${name}";
              mountPoint = "/home/${agentUser}";
              tag = "agent-home";
              proto = "virtiofs";
            }
            # Development folder for agent-specific projects
            {
              source = "${sharedDir}/${name}";
              mountPoint = "/home/${agentUser}/dev";
              tag = "agent-dev";
              proto = "virtiofs";
            }
            # Shared folder used across agent microvms, allowing them to pass
            # files, etc
            {
              source = "${sharedDir}/agents-share";
              mountPoint = "/home/${agentUser}/shared";
              tag = "agent-share";
              proto = "virtiofs";
            }
            # Secrets exposed from sops
            # FIXME: Switch this and any other secrets to a /run-based folder, and also
            # make it a generic secret store for multiple things on the guest (like api keys, etc)
            {
              source = "${microvmState}/${name}-sshd";
              mountPoint = "/var/lib/sshd-hostkeys";
              tag = "agent-sshd";
              proto = "virtiofs";
            }
          ];
        };

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
  options.${namespace}.ai-agents = {
    vms = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything); # FIXME: make a type
      default = { };
      description = "List of ai agent microvms to setup";
    };
  };

  imports = [
    inputs.microvm.nixosModules.host
  ];

  config = lib.mkIf (lib.length (lib.attrNames cfg.vms) != 0) {

    # FIXME: Should track the uid:gid for the microvm somewhere instead of hardcoding 1000?
    # I guess ideally we want it to match the UID on the host as well?
    systemd.tmpfiles.rules = [
      "d ${microvmState}           0750 ${config.hostSpec.primaryUsername} users -"
      "d ${sharedDir}              0750 ${config.hostSpec.primaryUsername} users -"
      "d ${sharedDir}/agents-share 0750 1000 1000 -"
    ]
    ++ (
      agents
      |> lib.attrNames
      |> map (name: [
        "d ${sharedDir}/${name}          0750 ${config.hostSpec.primaryUsername} users -"
        "d ${microvmState}/${name}       0750 1000  1000  -"
        "d ${microvmState}/${name}-sshd  0700 root  root  -"
      ])
      |> lib.flatten
    );

    sops.secrets =
      agents
      |> lib.attrNames
      |> lib.map (name: {
        "microvms/keys/ssh/${name}" = {
          owner = "root";
          group = "root";
          mode = "0400";
          # See systemd prep script below
          # path = "${microvmState}/${name}-sshd/ssh_host_ed25519_key";
        };
      })
      |> lib.mergeAttrsList;

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
          } ${microvmState}/${name}-sshd/ssh_host_ed25519_key
        '')
        |> lib.concatStringsSep "\n";
    };

    ${namespace}.agents-vpn.enable = true;
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

        # FIXME: Double check this
        routingPolicyRules = [
          {
            # Allow access between the guest and the host
            routingPolicyRuleConfig = {
              From = agent-lan.cidr;
              To = agent-lan.cidr;
              Table = "main";
              Priority = 999;
            };
          }
          # Route everything else over VPN
          {
            routingPolicyRuleConfig = {
              From = agent-lan.cidr;
              Table = 42; # wg-proton-agents table
              Priority = 1000;
            };
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

    # FIXME: Revisit this
    # Strict Outbound NAT only for packets escaping out the Proton Interface
    networking.nftables = {
      enable = true;
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

              # 3. TRAFFIC ROUTING THROUGH THE HOST (VM -> Internet via VPN)
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

    # FIXME: Switch this to route over VPN
    # networking.nat = {
    #   enable = true;
    #   internalInterfaces = [ "vbr-agents" ];
    # };

    # Only enable this if you want your microvm's to be able to access host services
    # networking.firewall.trustedInterfaces = [ agentsBridge ];

    microvm.vms = lib.mapAttrs mkAgentVm agents;
    passthru.microvms = config.microvm.vms;
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
