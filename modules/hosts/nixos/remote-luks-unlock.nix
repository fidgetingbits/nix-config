{ config, lib, ... }:
let
  cfg = config.services.remoteLuksUnlock;
in
{
  options = {
    services.remoteLuksUnlock = {
      enable = lib.mkEnableOption "Boot-time remote LUKS decrypt unlock service";
      key = lib.mkOption rec {
        type = lib.types.path;
        default = lib.custom.relativeToRoot "hosts/nixos/${config.hostSpec.hostName}/initrd_ed25519_key";
        example = default;
        description = "sshd private key as generated with ssh-keygen -t ed25519 -f initrd_ed25519_key or similar.\nNOTE: This file should be encrypted with git-crypt or similar. See .gitattributes for example";

      };
    };
  };

  config = lib.mkIf config.services.remoteLuksUnlock.enable {
    boot.initrd = {
      systemd = {
        enable = true;
        # emergencyAccess = true;
        users.root.shell = "/bin/systemd-tty-ask-password-agent";
      };
      luks.forceLuksSupportInInitrd = true;
      # Setup the host key as a secret in initrd, so it's not exposed in the /nix/store
      # this is all too earlier for sops
      secrets = lib.mkForce { "/etc/secrets/initrd/ssh_host_ed25519_key" = cfg.key; };
      network = {
        enable = true;
        ssh = {
          enable = true;
          port = config.hostSpec.networking.ports.tcp.ssh;
          authorizedKeys = config.users.users.${config.hostSpec.username}.openssh.authorizedKeys.keys;
          hostKeys = [ "/etc/secrets/initrd/ssh_host_ed25519_key" ];
        };
      };
    };
  };
}
