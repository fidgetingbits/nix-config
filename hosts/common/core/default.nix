# This file (and the global directory) holds config that I use on all hosts except nixos-installer.
# It imports foundation.nix as a base (which is used by nixos-installer) and builds on that for all hosts.
# IMPORTANT: This is used by NixOS and nix-darwin so options must exist in both!
{
  inputs,
  outputs,
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
let
  sopsFolder = (builtins.toString inputs.nix-secrets) + "/sops";
  platform = if isDarwin then "darwin" else "nixos";
  platformModules = "${platform}Modules";
in
{
  imports = lib.flatten [
    inputs.home-manager.${platformModules}.home-manager
    inputs.sops-nix.${platformModules}.sops
    inputs.disko.${platformModules}.disko
    inputs.nix-index-database.${platformModules}.nix-index

    (map lib.custom.relativeToRoot [
      "modules/common"
      "modules/${platform}"
      "hosts/common/core/sops.nix" # Core because it's used for backups, mail
      "hosts/common/core/ssh.nix"
      "hosts/common/core/${platform}.nix"
      "hosts/common/users/primary"
      "hosts/common/users/primary/${platform}.nix"
    ])
  ];

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
    overlays = [
      inputs.talon-nix.overlays.default
      outputs.overlays.default
    ];
  };

  sops.secrets = {
    # formatted as extra-access-tokens = github.com=<PAT token>
    "tokens/nix-access-tokens" = {
      sopsFile = "${sopsFolder}/shared.yaml";
    };
  };
  nix =
    {
      settings = {
        # See https://jackson.dev/post/nix-reasonable-defaults/
        connect-timeout = 5;
        log-lines = 25;
        min-free = 128000000; # 128MB
        max-free = 1000000000; # 1GB
        experimental-features = "nix-command flakes"; # Enable flakes and new 'nix' command
        auto-optimise-store = true; # Deduplicate and optimize nix store
        warn-dirty = false;
        allow-import-from-derivation = true;
        trusted-users = [ "@wheel" ];
        builders-use-substitutes = true;
        fallback = true; # Don't hard fail if a binary cache isn't available, since some systems roam
        substituters = [ ];
        extra-substituters =
          [
            "https://nix-community.cachix.org" # Nix community Cachix server
          ]
          ++ lib.optionals config.hostSpec.useAtticCache [
            "https://atticd.ooze.${config.hostSpec.domain}" # My attic server
          ];
        trusted-public-keys =
          [
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          ]
          ++ lib.optionals config.hostSpec.useAtticCache [
            "o-cache:TA5fD0hG38GHJo1z3rSoPnrBgZalPddmEh5DSn0DipA="
          ];

      };

      # Access token prevents github rate limiting if you have to nix flake update a bunch
      extraOptions = "!include ${config.sops.secrets."tokens/nix-access-tokens".path}";

      # Disabled because I am using nh
      # gc = {
      #   automatic = true;
      #   options = "--delete-older-than 10d";
      # };
    }
    // (lib.optionalAttrs pkgs.stdenv.isLinux {
      # This will add each flake input as a registry
      # To make nix3 commands consistent with your flake
      registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

      # This will add your inputs to the system's legacy channels
      # Making legacy nix commands consistent as well, awesome!
      # NOTE: on darwin I was getting:
      # error: The option `nix.registry.nixpkgs.to.path' has conflicting definition values:
      #   - In `/nix/store/3m75mdiiq4bkzm5qpx6arapz042na0vh-source/modules/nix': "/nix/store/m1g5a7agja7si7y9l1lzwhp3capbv7x9-source"
      #   - In `/nix/store/3m75mdiiq4bkzm5qpx6arapz042na0vh-source/modules/nix/nixpkgs-flake.nix': "/nix/store/fj58bk5dvyaxqfrsrncfg3bn1pmdj8q2-source"
      #   Use `lib.mkForce value` or `lib.mkDefault value` to change the priority on any of these definitions.
      nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    });
  networking.hostName = config.hostSpec.hostName;

  # System-wide packages, in case we log in as root
  environment.systemPackages = [ pkgs.openssh ];

  # Force home-manager to use global packages
  home-manager.useGlobalPkgs = true;
  # If there is a conflict file that is backed up, use this extension
  home-manager.backupFileExtension = "bk";
  # home-manager.useUserPackages = true;

  # On darwin it's important this is outside home-manager
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    promptInit = "source ''${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
  };

  # Probably use knownHostsFiles to add some extra secrets rather than spell them all out
  # Modern entries are hashed:
  # https://security.stackexchange.com/questions/56268/ssh-benefits-of-using-hashed-known-hosts
  # https://serverfault.com/questions/331080/what-do-the-different-parts-of-known-hosts-entries-mean
  # We should hash them ourselves as part of this
  # Format:
  # |1|F1E1KeoE/eEWhi10WpGv4OdiO6Y=|3988QV0VE8wmZL7suNrYQLITLCg= ssh-rsa ...
  # |1| - Means it's hashed
  # F1E1KeoE/eEWhi10WpGv4OdiO6Y= - Salt
  # 3988QV0VE8wmZL7suNrYQLITLCg= - Hash
  # ssh-rsa ... - The rest of the line
  # builtins.hashString
  # This is Linux only?

  hostSpec = {
    username = "aa";
    handle = "fidgetingbits";
    inherit (inputs.nix-secrets)
      domain
      email
      userFullName
      networking
      work
      ;
  };

  # FIXME(darwin): I'm not sure this works on darwin...
  security.pki.certificates = lib.flatten (
    lib.optional config.hostSpec.isWork inputs.nix-secrets.work.certificates
  );
}
