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

  mkRosenpassPeer = role: host: {
    public_key = secretsFolder + "/keys/${host.name}_pqpk";
    peer = host.wgpk;
    endpoint = lib.optionalString (
      role == "client"
    ) "${cfg.endpoint}:${toString cfg.networkParams.rosenpassPort}";
  };
  mkRosenpassPeers = role: hosts: (map (host: mkRosenpassPeer role host) hosts);
  # FIXME: These could move to lib.custom.network, since they duplicate with ./server.nix
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
  imports = [
    ./server.nix
    ./client.nix
  ];
  options.${namespace}.wireguard = {
    enable = lib.mkEnableOption "PQ Wireguard";
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
    peerNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      example = [ "gibson" ];
      description = "The list of peers. For a client, put the server only. For server, put all clients";
    };
    allowedIPs = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      example = [ "192.168.0.0/24" ];
      description = "List of allowed IPs for the client when accessing the server";
    };
    endpoint = lib.mkOption {
      type = lib.types.str;
      example = "192.168.1.100";
      description = "Server IP or domain for clients to connect to.";
    };
    # FIXME: Probably rework this
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
        dns = "192.168.0.1";
        domain = "example.com";
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
    # See ./client.nix or ./server.nix for role-specific settings
    networking = {
      wireguard = {
        interfaces = {
          ${cfg.interface} = {
            listenPort = cfg.networkParams.wireguardPort;
            ips = [ (genWireguardIP hostName) ];
            privateKeyFile = config.sops.secrets."keys/wireguard/wgsk".path;
          };
        };
      };
    };
    services.rosenpass = {
      enable = true;
      defaultDevice = cfg.interface;
      settings = {
        verbosity = "Verbose";
        public_key = secretsFolder + "/keys/${hostName}_pqpk";
        secret_key = config.sops.secrets."${hostName}_pqsk".path;
        peers =
          cfg.peerNames
          |> map (name: cfg.hosts.${name})
          # nixfmt hack
          |> mkRosenpassPeers cfg.role;
      };
    };

    systemd.services.rosenpass = {
      after = [
        "network-online.target"
      ];
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
  };
}
