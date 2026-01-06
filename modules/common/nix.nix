# Nix settings that are common to hosts and home-manager configs
{
  inputs,
  config,
  lib,
  pkgs,
  namespace,
  osConfig ? { },
  ...
}:
let
  # FIXME: This allows us to access the settings from HM
  hostSpec = if (config ? hostSpec) then config.hostSpec else osConfig.hostSpec;
in
{
  options.${namespace}.nix = {
    withSecrets = lib.mkOption {
      type = lib.types.bool;
      default = hostSpec.isLocal;
      example = false;
      description = "Include netrc and github token secrets used by trusted systems on local networks";
    };
    sopsFile = lib.mkOption {
      type = lib.types.path;
      default = (builtins.toString inputs.nix-secrets) + "/sops/olan.yaml";
      description = "sops file containing nix access token and netrc contents";
    };
  };

  config = lib.mkMerge [
    {
      nix = {
        # We want at least 2.30 to get the memory management improvements
        # https://discourse.nixos.org/t/nix-2-30-0-released/66449/4
        package = lib.mkForce pkgs.unstable.nixVersions.git;
        settings = {
          # See https://jackson.dev/post/nix-reasonable-defaults/
          connect-timeout = 5;
          log-lines = 25;
          min-free = 128000000; # 128MB
          max-free = 1000000000; # 1GB
          experimental-features = [
            "nix-command"
            "flakes"
            "pipe-operators"
          ];
          warn-dirty = false;
          allow-import-from-derivation = true;
          trusted-users = [ "@wheel" ];
          builders-use-substitutes = true;
          fallback = true; # Don't hard fail if a binary cache isn't available, since some systems roam
          substituters = lib.flatten [
            (lib.optional (lib.substring 0 4 hostSpec.timeZone == "Asia") [
              "https://mirror.sjtu.edu.cn/nix-channels/store" # Shanghai Jiao Tong University
              "https://mirrors.ustc.edu.cn/nix-channels/store" # USTC backup mirror
            ])
            [
              "https://cache.nixos.org" # Official global cache
              "https://nix-community.cachix.org" # Community packages
            ]
          ];
          extra-trusted-public-keys = [
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          ];

          # FIXME: This might not only contain attic-related entries in the future
          netrc-file =
            if ((config ? "sops") && (hostSpec.useAtticCache)) then
              "${config.sops.secrets."passwords/netrc".path}"
            else
              null;
        };

        # Access token prevents github rate limiting if you have to nix flake update a bunch
        # Only local systems are used to build anything, so only include there
        extraOptions =
          lib.optionalString ((config ? "sops") && (hostSpec.isLocal))
            "!include ${config.sops.secrets."tokens/nix-access-tokens".path}";

        # Disabled because I am using nh
        # gc = {
        #   automatic = true;
        #   options = "--delete-older-than 10d";
        # };

        # This will add each flake input as a registry
        # To make nix3 commands consistent with your flake
        registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

        # This will add your inputs to the system's legacy channels
        # Making legacy nix commands consistent as well
        nixPath =
          config.nix.registry
          # nixfmt hack
          |> lib.mapAttrsToList (key: value: "${key}=${value.to.path}");

      };
    }
  ];
}
