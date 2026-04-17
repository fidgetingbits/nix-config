# Module for configuring pq-safe wireguard server and client
#
# Currently tested and setup for ipv4 only. Also assumes you want to derive
# your wg IPs from your LAN ips
#
# See gen-wireguard-keys utility for generating wg/pq keys for multiple hosts
#
{
  config,
  lib,
  inputs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.wireguard;
  secretsFolder = builtins.toString inputs.nix-secrets;
  sopsFolder = secretsFolder + "/sops/";
  hostName = config.networking.hostName;
  iifname = "wg0";
  mkWireguardPeer = role: host: {
    publicKey = host.wgpk;
    allowedIPs = if (role == "client") then cfg.allowedIPs else [ (genWireguardIP host.name) ];
    endpoint =
      if (role == "client") then
        # FIXME: Maybe need a cfg.endpoint instead, in case client doesn't want to use domain?
        "${host.name}.${config.hostSpec.domain}:${toString cfg.networkParams.wireguardPort}"
      else
        null;
    # Needed on clients for keeping NAT open
    persistentKeepalive = if role == "client" then 25 else null;
  };
  mkWireguardPeers = role: hosts: (map (host: mkWireguardPeer role host) hosts);
  mkRosenpassPeer = role: host: {
    public_key = secretsFolder + "/keys/${host.name}_pqpk";
    peer = host.wgpk;
    endpoint =
      if (role == "client") then
        "${host.name}.${config.hostSpec.domain}:${toString cfg.networkParams.rosenpassPort}"
      else
        null;
  };
  mkRosenpassPeers = role: hosts: (map (host: mkRosenpassPeer role host) hosts);
  subnetPrefix =
    ip:
    ip
    |> lib.splitString "."
    |> lib.take 3
    # nixfmt hack
    |> lib.concatStringsSep ".";
  lastOctet =
    ip:
    ip
    |> lib.splitString "."
    # nixfmt hack
    |> lib.last;
  genWireguardIP =
    host: "${subnetPrefix cfg.networkParams.subnet}.${lastOctet cfg.hosts.${host}.ip}/32";
in
{
  options.${namespace}.wireguard = {
    enable = lib.mkEnableOption "PQ Wireguard";
    role = lib.mkOption {
      type = lib.types.enum [
        "server"
        "client"
      ];
    };
    externalInterface = lib.mkOption {
      type = lib.types.str;
      example = "en0";
      description = "Value of external interface for the server";
    };
    peerNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      example = [ "gibson" ];
      description = "The list of peers. For a client, put the server. For server, put all clients";
    };
    allowedIPs = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      example = [ "192.168.0.0/24" ];
      description = "List of allowed IPs for the client when accessing the server";
    };
    networkParams = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.oneOf [
          lib.types.str
          lib.types.int
        ]
      );
      example = {
        subnet = "192.168.0.1/24";
        wiregardPort = 51820;
        rosenpassPort = 9999;
      };
      description = "Core information about the wireguard network";
    };
    hosts = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      example = {
        hostA = {
          name = "hostA";
          ip = "192.168.1.2";
          wgpk = "abcdef";
        };
      };
      # FIXME: We probably want to make it so the IP address derivation is optional
      description = ''
        An attribute set of hosts containing IP address, wireguard public key

        Note that the IP address is assumed to be the IP of the host on the LAN, and the
        wireguard subnet IP is derived from it so the last octet is shared.
      '';
    };
  };
  config = lib.mkIf cfg.enable {
    networking = {
      nat = lib.mkIf (cfg.role == "server") {
        enable = true;
        enableIPv6 = false;
        internalInterfaces = [ iifname ];
        inherit (cfg) externalInterface;
      };

      firewall.allowedUDPPorts = lib.mkIf (cfg.role == "server") [
        cfg.networkParams.wireguardPort
        cfg.networkParams.rosenpassPort
      ];

      wg-quick = {
        interfaces = {
          ${iifname} = {
            peers =
              cfg.peerNames
              |> map (name: cfg.hosts.${name})
              # nixfmt hack
              |> mkWireguardPeers cfg.role;
            listenPort = cfg.networkParams.wireguardPort;
            address = [ (genWireguardIP hostName) ];
            privateKeyFile = config.sops.secrets."keys/wireguard/wgsk".path;
          };
        };
      };
    };

    services.rosenpass = {
      enable = true;
      defaultDevice = iifname;
      settings = {
        verbosity = "Verbose";
        public_key = secretsFolder + "/keys/${hostName}_pqpk";
        secret_key = config.sops.secrets."${hostName}_pqsk".path;
        listen =
          if cfg.role == "server" then [ "0.0.0.0:${toString cfg.networkParams.rosenpassPort}" ] else [ ];
        peers =
          cfg.peerNames
          |> map (name: cfg.hosts.${name})
          # nixfmt hack
          |> mkRosenpassPeers cfg.role;
      };
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

    assertions = [
      {
        assertion = (cfg.role == "server" && cfg.allowedIPs == null);
        message = "The allowedIPs option shouldn't be set for the server, as it is automatically configured using cfg.hosts";
      }
    ];
  };
}
