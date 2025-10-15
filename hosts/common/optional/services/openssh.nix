{
  lib,
  config,
  ...
}:
let
  sshPort = config.hostSpec.networking.ports.tcp.ssh;

  # NOTE: This slightly odd way of using both was to avoid infinite recursion. Also having both is
  # currently due to granularFirewall not supporting darwin and nftables yet
  cfg = config.networking.granularFirewall;
  granularFirewallRules = lib.mkIf cfg.enable {
    networking.granularFirewall.allowedRules = [
      {
        serviceName = "ssh";
        protocol = "tcp";
        ports = [ sshPort ];
        hosts = config.hostSpec.networking.rules.${config.hostSpec.hostName}.sshAllowedHosts;
      }
    ];
  };
  regularFirewallRules = lib.mkIf (cfg.enable == false) {
    networking.firewall.allowedTCPPorts = [ sshPort ];
  };
in
{
  # FIXME(sshguard): Setup per-network whitelists, etc
  imports = [ ./sshguard.nix ];
}
//

  lib.mkMerge [
    {

      # FIXME: Drop older key types and stuff since we should never be using them anyway
      services.openssh = {
        enable = true;
        ports = [ sshPort ];
        # Fix LPE vulnerability with sudo abusing SSH_AUTH_SOCK: https://github.com/NixOS/nixpkgs/issues/31611
        authorizedKeysFiles = lib.mkForce [ "/etc/ssh/authorized_keys.d/%u" ];
        settings = {
          # Harden
          PasswordAuthentication = false;
          PermitRootLogin = "no";
          # Automatically remove stale sockets
          StreamLocalBindUnlink = "yes";
          # Allow forwarding ports to everywhere
          GatewayPorts = "clientspecified";
        };

        hostKeys = [
          {
            path = "${config.hostSpec.persistFolder}/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
      };

      services.per-network-services.trustedNetworkServices = [ "sshd" ];

      # Allow sudo over ssh with yubikey
      security.pam = {
        rssh.enable = true;
        services.sudo.rssh = true;
      };
    }
    granularFirewallRules
    regularFirewallRules
  ]
