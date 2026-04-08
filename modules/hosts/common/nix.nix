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
  isNixOS = (config ? hostSpec);
  # NOTE: Differentiate NixOS and HM
  hostSpec = if isNixOS then config.hostSpec else osConfig.hostSpec;
  overridesFile = "/etc/nix/network-overrides.conf";
  dispatcherScript = pkgs.writeShellApplication {
    name = "check-nix-builders.sh";
    runtimeInputs = lib.attrValues {
      inherit (pkgs)
        util-linux # logger
        coreutils
        curlMinimal
        openssh
        gawk
        ;
    };
    text =
      # bash
      ''
        LOG_TAG="nix-check-builders"
        OVERRIDES_CONF=""
        function check_substituters() {
            # Disable any substituters that aren't accessible to prevent build spam/errors
            extra_subs=$(grep "extra-substituters" /etc/nix/nix.conf | cut -d= -f2)
            # shellcheck disable=SC2181
            if [ "$?" -eq 0 ]; then
              read -ra all_subs <<<"$extra_subs"
              declare -a accessible_subs=()
              for url in "''${all_subs[@]}"; do
                  if [ "$url" == "" ]; then
                      continue
                  fi
                  url=$(echo "$url" | cut -d/ -f1-3)
                  if runuser -u nobody -- curl -IsL --connect-timeout 1 "$url" | grep -q "200"; then
                      accessible_subs+=("$url")
                  else
                      logger -t "$LOG_TAG" "✘ extra-substituter $url is down"
                  fi
              done
              if [ "''${#accessible_subs[@]}" -ne "''${#all_subs[@]}" ]; then
                  OVERRIDES_CONF=$(echo -e "''${OVERRIDES_CONF:-}\nextra-substituters = ''${accessible_subs[*]}")
              fi
            fi
        }

        function check_builders() {
            mapfile -t all_builders < <(grep -v '^#' /etc/nix/machines)
            declare -a accessible_builders=()
            for builder in "''${all_builders[@]}"; do
                [[ -z "$builder" ]] && continue
                host=$(echo "$builder" | awk '{print $1}' | sed 's|ssh://||')
                # FIXME: Double check this is always the case?
                keyFile=$(echo "$builder" | awk '{print $3}')

                if ssh -q -o ConnectTimeout=2 -o BatchMode=yes -i "$keyFile" "$host" exit 0 >/dev/null 2>&1; then
                    accessible_builders+=("$builder")
                else
                    logger -t "$LOG_TAG" "✘ builder $host is unreachable, skipping"
                fi
            done
            if [ "''${#accessible_builders[@]}" -lt "''${#all_builders[@]}" ]; then
                IFS=';'
                OVERRIDES_CONF=$(echo -e "''${OVERRIDES_CONF:-}\nbuilders = ''${accessible_builders[*]}")
                unset IFS
            fi
        }

        # shellcheck disable=SC2034
        INTERFACE=$1
        ACTION=$2

        case "$ACTION" in
            up|down)
                logger -t "$LOG_TAG" "Validating nix substituters and builders connectivity"
                check_substituters
                check_builders
                if [ "$OVERRIDES_CONF" == "" ]; then
                  logger -t "$LOG_TAG" "All substituters and builders are accessible"
                fi
                echo "$OVERRIDES_CONF" > ${overridesFile}
                ;;
        esac
      '';
  };
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
      default = (toString inputs.nix-secrets) + "/sops/olan.yaml";
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

        }
        // lib.optionalAttrs (config.hostSpec.isMinimal == false && hostSpec.useAtticCache) {
          # FIXME: This might not only contain attic-related entries in the future
          netrc-file = if config ? "sops" then "${config.sops.secrets."passwords/netrc".path}" else null; # FIXME: This is busted if set to null (fixed by isMinimal check above for now).
        };

        extraOptions = ''
          ${lib.optionalString ((config ? "sops") && (hostSpec.isLocal)) ''
            # Access token prevents github rate limiting if you have to nix flake update a bunch
            # Only local systems are used to build anything, so only include there
            !include ${config.sops.secrets."tokens/nix-access-tokens".path}
          ''}
          ${lib.optionalString hostSpec.isRoaming ''
            # Roaming systems may not have access to builders or caches, and nix doesn't gracefully
            # handle when they are inaccessible. These overrides are dropped by a network
            # dispatcher script and selectively disable some settings
            !include /etc/nix/network-overrides
          ''}
        '';

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

      # FIXME: This not complaining implies that home-manager doesn't actually parse this file?
      networking.networkmanager.dispatcherScripts = lib.optionals (isNixOS && hostSpec.isRoaming) [
        {
          source = lib.getExe dispatcherScript;
        }
      ];
    }
  ];
}
