{
  inputs,
  config,
  lib,
  pkgs,
  hostSpec,
  ...
}:
{
  imports = lib.flatten [
    inputs.impermanence.nixosModules.home-manager.impermanence
    (map lib.custom.relativeToRoot [
      "modules/common/"
      "modules/home/"
    ])
    (lib.custom.scanPathsFilterPlatform ./.)
  ];

  inherit hostSpec;

  home.packages =
    let
      # FIXME: This should move to packages
      json5-jq = pkgs.stdenv.mkDerivation {
        name = "json5-jq";

        src = pkgs.fetchFromGitHub {
          owner = "wader";
          repo = "json5.jq";
          rev = "ac46e5b58dfcdaa44a260adeb705000f5f5111bd";
          sha256 = "sha256-xBVnbx7L2fhbKDfHOCU1aakcixhgimFqz/2fscnZx9g=";
        };

        dontBuild = true;

        installPhase = ''
          mkdir -p $out/share
          cp json5.jq $out/share/json5.jq
        '';
      };

      jq5 = pkgs.writeShellScriptBin "jq5" ''
        # Initialize arrays for options and query parts
        declare -a JQ_OPTS=()
        declare -a QUERY_PARTS=()

        # Collect arguments
        while [ $# -gt 1 ]; do
          if [[ $1 == -* ]]; then
            JQ_OPTS+=("$1")
          else
            QUERY_PARTS+=("$1")
          fi
          shift
        done

        # Last argument is always the file
        FILE="$1"

        # Join query parts with spaces
        QUERY="$(printf "%s " "''${QUERY_PARTS[@]}")"

        if [ ''${#QUERY_PARTS[@]} -eq 0 ]; then
          # No query case
          jq -Rs -L "${json5-jq}/share/" "''${JQ_OPTS[@]}" 'include "json5"; fromjson5' "$FILE"
        else
          # Query case
          jq -Rs -L "${json5-jq}/share/" "''${JQ_OPTS[@]}" "include \"json5\"; fromjson5 | $QUERY" "$FILE"
        fi
      '';

    in
    [ jq5 ]
    ++ builtins.attrValues (
      {
        inherit (pkgs)
          eza # ls replacement
          zoxide # cd replacement
          fd # tree-style ls
          procs # ps replacement
          duf # df replacement
          ripgrep # grep replacement
          du-dust # du replacement
          p7zip # archive
          pstree # tree-style ps
          lsof # list open files
          tealdeer # smaller man pages
          eva # cli calculator
          hexyl # hexdump replacement
          grc # colorize output
          # toybox # decode uuencoded files (conflicts with llvm binutils wrapper)
          fastfetch
          jq # json
          gnupg
          yq-go # yaml
          dig

          findutils # find
          file # file type analysis
          nix-tree # show nix store contents
          openssh

          libnotify # for notify-send

          # network utilities
          iputils # ping, traceroute, etc

          magic-wormhole # Convenient file transfer

          # FIXME: This likely isn't needed as core, since we can use dev flake for it
          pre-commit # git hooks
          ;

      }
      // lib.optionalAttrs (config.hostSpec.isProduction) {
        inherit (pkgs.llvmPackages)
          bintools # strings, etc
          ;
      }
      // lib.optionalAttrs (config.hostSpec.isProduction && (!config.hostSpec.isServer)) {
        inherit (pkgs)
          ##
          # Core GUI Utilities
          ##
          evince # pdf reader
          zathura # pdf reader

          mdcat # Markdown preview in cli

          xsel # X clipboard manager

          ;
        inherit (pkgs.unstable)
          ##
          # Core GUI Utilities
          ##
          obsidian # note taking
          ;
      }

    );

  programs.bash.enable = true;
  programs.home-manager.enable = true;
  # even better top
  programs.btop = {
    enable = true;
    settings = {
    };
  };

  # FIXME: This is duplicated with the users generate code
  home.stateVersion = "23.05";
}
