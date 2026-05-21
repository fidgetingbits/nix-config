# FIXME: Since this is agent specific, maybe we move it
{
  pkgs,
  lib,
  config,
  inputs,
  namespace,
  ...
}:
let
  secretsFolder = builtins.toString inputs.nix-secrets;
  sopsFolder = secretsFolder + "/sops/";
  hostName = config.networking.hostName;
  cfg = config.${namespace}.agents-vpn;
  vpn = config.hostSpec.networking.vpn.wg-proton-agents;
  ifname = "agents-vpn";
  wireguardPort = 51821;
in
{
  options.${namespace}.agents-vpn = {
    enable = lib.mkEnableOption "Enable vpn wireguard interface for ai-agents";
  };
  config = lib.mkIf cfg.enable {
    networking.wireguard.interfaces.${ifname} = {
      ips = [ "10.2.0.2/32" ];

      allowedIPsAsRoutes = false;
      peers = [
        {
          allowedIPs = [
            "0.0.0.0/0" # Don't use 0.0.0.0 to prevent auto-routing everything on host
          ];
          inherit (vpn) publicKey endpoint;
        }
      ];
      privateKeyFile = config.sops.secrets."keys/wireguard/proton_agents_sk".path;
      listenPort = wireguardPort; # IMPORTANT: Must not conflict with other wireguard listener
      # FIXME: Label the table number somewhat more sanely to correlate between the agent files
      postSetup = ''
        ${pkgs.iproute2}/bin/ip route add default dev ${ifname} table 42
      '';
    };

    networking.firewall.checkReversePath = "loose";

    environment.systemPackages = [ pkgs.wireguard-tools ];

    # FIXME: Revisit what file this is in, since at least ossa/oedo will both use
    sops.secrets = {
      "keys/wireguard/proton_agents_sk" = {
        sopsFile = "${sopsFolder}/${hostName}.yaml";
      };
    };
  };
}
