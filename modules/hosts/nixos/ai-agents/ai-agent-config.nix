# This is a module defining data to be placed inside of a microvm
# NOTE: Do not assume other modules/config are accessible unless
# explicitly added in the main microvm declaration
{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  cfg = config.${namespace}.microvm;
in
{
  options.${namespace}.microvm = {
    name = lib.mkOption {
      type = lib.types.str;
      description = "Name of microvm guest.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      description = ''
        Name of microvm user.

        NOTE: If you plan to share coding projects between your host/guest,
        you likely need the paths synced, so recommend using the same
        username
      '';
      default = "user";
    };
    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "CLI packages to install inside the guest.";
    };
    sshPort = lib.mkOption {
      type = lib.types.port;
      description = "Loopback port sshd listens on inside the guest.";
    };
    hostAuthorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH public keys authorized to access microvm shell";
    };
    extraConfig = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Any additional NixOS configuration for inside the microvm";
    };
  };

  config = {
    users.mutableUsers = false;
    users.allowNoPasswordLogin = true;

    users.users.${cfg.user} = {
      isNormalUser = true;
      uid = 1000; # FIXME: Needs to be configurable? Needs to be relayed to shared folders somehow
      home = "/home/${cfg.user}";
      createHome = true;
      # FIXME: Make this inherit some hm niceties
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = cfg.hostAuthorizedKeys;
    };

    programs.zsh.enable = true;

    users.groups.${cfg.user}.gid = 1000;

    # FIXME: Revisit these defaults (overlay our neovim package, etc?)
    environment.systemPackages =
      cfg.packages
      ++ (with pkgs; [
        git
        curl
        jq
        ripgrep
        python3
        openssh
        neovim
        strace
      ]);

    services.openssh = {
      enable = true;
      ports = [ cfg.sshPort ];
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;

        # Don't bother with rsa keys, since we are only connecting from our host
        PubkeyAcceptedAlgorithms = "ssh-ed25519";
        HostKeyAlgorithms = "ssh-ed25519";
      };
      listenAddresses = [
        {
          addr = "0.0.0.0";
          port = cfg.sshPort;
        }
      ];
      # Persist sshd host keys on a bind-mounted path so they survive
      # VM/container rebuilds and clients don't see host-key-changed warnings.
      # FIXME: Update this to use impermanence and put /persist/etc stored on the host probably?
      # See this thread: https://github.com/microvm-nix/microvm.nix/issues/52
      hostKeys = [
        {
          path = "/var/lib/sshd-hostkeys/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];
    };

    networking.firewall.allowedTCPPorts = [ cfg.sshPort ];

    # Basic page-cache bug hardening
    boot.blacklistedKernelModules = [
      "af_alg"
      "algif_aead"
      "algif_skcipher"
      "algif_hash"
      "algif_rng"

      "esp4"
      "esp6"
      "rxrpc"
    ];
    boot.extraModprobeConfig =
      let
        false = "${pkgs.coreutils}/bin/false";
      in
      ''
        install af_alg         ${false}
        install algif_aead     ${false}
        install algif_skcipher ${false}
        install algif_hash     ${false}
        install algif_rng      ${false}
        install authenc        ${false}
        install authencesn     ${false}

        install esp4           ${false}
        install esp6           ${false}
        install rxrpc          ${false}
      '';
    time.timeZone = "UTC";
  };
}
