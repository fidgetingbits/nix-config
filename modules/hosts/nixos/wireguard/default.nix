# Implement a PQ-safe client/server wireguard VPN. It is not entirely generic
# so it may not just work without some tweaks.
#
# Depends on helper functions from
# [introdus](https://codeberg.org/fidgetingbits/introdus/src/branch/main/lib/network.nix)
#
{
  config,
  lib,
  inputs,
  namespace,
  pkgs,
  ...
}:
let
  cfg = config.${namespace}.wireguard;
  secretsFolder = lib.toString inputs.nix-secrets;
  sopsFolder = secretsFolder + "/sops/";
  hostName = config.networking.hostName;

  # Not all wireguard peers will have rosenpass support (eg: android), so check if the
  # host has a key defined, and if not they get filtered out
  mkRosenpassPeer =
    role: host:
    let
      public_key = secretsFolder + "/keys/${host.name}_pqpk";
      keyExists = lib.pathExists public_key;
    in
    if keyExists then
      {
        inherit public_key;
        peer = host.wireguardPubKey;
        endpoint = if (role == "client") then "${cfg.endpoint}:${toString cfg.rosenpassPort}" else null;
      }
    else
      lib.warnIf (!keyExists && !(lib.elem host.name cfg.rosenpassExempt))
        "${host.name} doesn't have a rosenpass public key and isn't white listed. This may impact VPN session security."
        { };
  mkRosenpassPeers =
    role: hosts:
    hosts
    |> map (host: mkRosenpassPeer role host)
    # nixfmt hack
    |> lib.filter (peer: lib.length (lib.attrNames peer) > 0);
in
{
  imports = [
    ./server.nix
    ./client.nix
  ];
  options.${namespace}.wireguard = {
    enable = lib.mkEnableOption "Post-Quantum Wireguard";
    role = lib.mkOption {
      type = lib.types.enum [
        "server"
        "client"
      ];
    };
    interface = lib.mkOption {
      type = lib.types.str;
      default = "wg0";
      example = "wg0";
      description = "Name of interface to use for wireguard connection";
    };

    externalInterface = lib.mkOption {
      type = lib.types.str;
      example = "en0";
      description = "Value of external interface for server outbound routing or client DNS rules, etc";
    };

    allowedIPs = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      example = [ "192.168.0.0/24" ];
      description = "List of allowed IPs for the client when accessing the server";
    };
    endpoint = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "192.168.1.100";
      description = "Server IP or domain for clients to connect to.";
    };

    subnet = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      example = { }; # FIXME
      description = "Subnet of the VPN network";
    };

    wireguardPort = lib.mkOption {
      type = lib.types.int;
      example = 51820;
      description = "Wireguard UDP port";
    };

    rosenpassPort = lib.mkOption {
      type = lib.types.int;
      example = 9999;
      description = "Rosenpass UDP port";
    };

    rosenpassExempt = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      example = [ "hostA" ];
      description = "List of systems that won't use Rosenpass. e.g. An Android device.";
    };

    peers = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      example = [ { } ]; # FIXME
      description = "The list of peers. For a client, put the server only. For server, put all clients";
    };

    # FIXME: Finish the server-side part of this
    # FIXME: We should probably add a list of domains eventually
    dns = {
      enable = lib.mkEnableOption "On server, enabled will run a DNS server. On client, will setup resolution via network-resovled.";

      domain = lib.mkOption {
        type = lib.types.str;
        example = "example.com";
        description = "Domain lookup to route over VPN";
      };

      server = lib.mkOption {
        type = lib.types.str;
        example = "8.8.8.8";
        description = "DNS server on VPN network to use to resolve domain";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # See ./client.nix or ./server.nix for role-specific settings
    networking = {
      wireguard = {
        interfaces = {
          ${cfg.interface} = {
            listenPort = cfg.wireguardPort;
            ips = [
              "${cfg.subnet.hosts.${hostName}.ip}/32"
            ];
            privateKeyFile = config.sops.secrets."keys/wireguard/wgsk".path;
          };
        };
      };
    };

    # NOTE: On nixos-rebuild sometimes the wifi device isn't up yet depending on what services rebuilt,
    # but I guess network-online.target is flagged as done, so wireguard fails to start. This tries to
    # fix that by waiting for at least a default route to apply wireguard
    # FIXME: This might be only necessary on the clients? Not sure it matters
    systemd.services."wireguard-${cfg.interface}" = {
      preStart = ''
        echo "Waiting for default network gateway..."
        until ip route show default | grep -q default; do
          sleep 1
        done
        echo "Gateway found, proceeding."
      '';
    };

    services.rosenpass = {
      enable = true;
      defaultDevice = cfg.interface;
      settings = {
        verbosity = "Verbose";
        public_key = secretsFolder + "/keys/${hostName}_pqpk";
        secret_key = config.sops.secrets."${hostName}_pqsk".path;
        peers = mkRosenpassPeers cfg.role cfg.peers;
      };
    };

    systemd.services.rosenpass = {
      # Wait for wireguard to sop reStart can pull out the default interface
      # Also restart when wireguard goes down, otherwise seems to stall
      requires = [ "wireguard-${cfg.interface}.service" ];
      partOf = [ "wireguard-${cfg.interface}.service" ];

      serviceConfig = {
        # Often fails after resume from suspend, but should work eventually
        # so don't give up else we have no vpn and have to manually do it...
        #  8月 02 06:52:01 ossa rosenpass-start[3449421]: [2026-08-01T22:52:01Z ERROR rosenpass] peer 0 endpoint <domain>:<port> can not be parsed to a so
        Restart = "always";
        RestartSec = "1s";
        # Restart always
      };

      startLimitIntervalSec = 0;
    };

    sops.secrets = {
      "keys/wireguard/wgsk" = {
        sopsFile = "${sopsFolder}/${hostName}.yaml";
      };
      "${hostName}_pqsk" = {
        sopsFile = sopsFolder + "${hostName}_pqsk";
        format = "binary";
      };
    };

    environment.etc = {
      "wireguard/peer-names.json".text = lib.toJSON (
        lib.listToAttrs (
          map (p: {
            name = p.publicKey;
            value = if (lib.stringLength p.name) <= (lib.stringLength p.publicKey) then p.name else "unknown";
          }) config.networking.wireguard.interfaces.wg0.peers
        )
      );

      "systemd/resolved.conf.d/10-vpn-routing.conf".source =
        (pkgs.formats.ini { }).generate "10-vpn-routing"
          {
            Resolve = {
              DNS = "1.1.1.1";
              Domains = "~vpn.${config.hostSpec.domain}";
            };
          };
    };
  };
}
