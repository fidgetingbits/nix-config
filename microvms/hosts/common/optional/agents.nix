# This is a module defining data to be placed inside of a microvm
#
# NOTE: Do not assume other modules/config are accessible unless
# explicitly added in the main microvm declaration in ./default.nix
#
# IMPORTANT: Seems sops doesn't work, so we inject them at runtime
# from the host
{
  inputs,
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.microvm;
  user = cfg.user;
  sshKeyPath = "/run/secrets/ssh_host_ed25519_key";
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

  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  config = {

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = { inherit user inputs; };
      users.${user} = {
        imports = (
          map lib.custom.relativeToRoot [
            "microvms/home/common/core"
          ]
        );
      };
    };

    users = {
      mutableUsers = false;
      allowNoPasswordLogin = true;

      users.${user} = {
        isNormalUser = true;
        uid = 1000; # FIXME: Needs to be configurable? Needs to be relayed to shared folders somehow
        home = "/home/${user}";
        createHome = true;
        shell = pkgs.zsh;
        openssh.authorizedKeys.keys = cfg.hostAuthorizedKeys;
        # Secrets exposed in /run/micromv-secrets/{name} are scoped to this group
        extraGroups = [ "kvm" ];
      };

      groups.${user}.gid = 1000;
    };

    # agent has root in microvm
    security.sudo.extraRules = [
      {
        users = [ user ];
        commands = [
          {
            command = "ALL";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    systemd.tmpfiles.rules = [
      # Required when a volume is mounted as home (see ./default.nix)
      "d /home/${user} 0755 ${user} ${user} -"
      # Secrets mirror from host sops
      "d /run/secrets  2750 root kvm -"
    ];

    # ── Fix for microvm shutdown hang (issue #170) ────────────────
    # Without this, systemd tries to unmount /nix/store during
    # shutdown but umount lives in /nix/store → deadlock.
    # From https://github.com/FintanH/fintos/blob/67dd2cf6ae7db2bab2a7dd9825f604188565f2ef/microvm/base.nix
    systemd.mounts = [
      {
        what = "store";
        where = "/nix/store";
        overrideStrategy = "asDropin";
        unitConfig.DefaultDependencies = false;
      }
    ];

    # FIXME: Setup the numtide llm-agent.nix stuff
    # nixpkgs.overlays = [ (import ../overlays/default.nix { inherit inputs; }) ];

    environment.systemPackages = cfg.packages;
    environment.etc."vm-version".text = "generation-test-4";
    system.stateVersion = "26.05";
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    programs.zsh.enable = true;

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
          path = sshKeyPath;
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
