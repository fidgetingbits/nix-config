{ inputs, lib, ... }:
let
  overlays = {
    # Adds my custom packages
    # FIXME: Add per-system packages
    additions =
      final: prev:
      (prev.lib.packagesFromDirectoryRecursive {
        callPackage = prev.lib.callPackageWith final;
        directory = ../pkgs/common;
      }
        # Any nixpkgs PRs that aren't upstream yet
        # https://github.com/NixOS/nixpkgs/pull/355232
      )
      # Other external inputs
      // {
        #neovim = inputs.nixvim-flake.packages.${final.stdenv.hostPlatform.system}.default;
        neovim = inputs.nixcats-flake.packages.${final.stdenv.hostPlatform.system}.default;
        nixcats = inputs.nixcats-flake.packages.${final.stdenv.hostPlatform.system}.default;
        nix-sweep = inputs.nix-sweep.packages.${prev.stdenv.hostPlatform.system}.default;
      };

    linuxModifications =
      final: prev:
      if prev.stdenv.isLinux then
        prev.lib.packagesFromDirectoryRecursive {
          # We pass self so that we can do some relative path computation for binary
          # blobs not tracked in our repo config
          callPackage = prev.lib.callPackageWith final;
          directory = ../pkgs/nixos;
        }
        // {
          talon-unwrapped =
            let
              # Pull out the 0.4.0-411-g6d1e version part from talon-linux-115-0.4.0-411-g6d1e.tar.xz in beta-url
              beta = inputs.nix-secrets.talon-linux-beta;
              version = prev.lib.elemAt (prev.lib.match ".*talon-linux-[0-9]+-(.*).tar.xz" beta.url) 0;
            in
            prev.talon-unwrapped.overrideAttrs (oldAttrs: {
              inherit version;
              src = prev.fetchurl {
                inherit (beta) url sha256;
              };
            });
          # FIXME: error: function 'anonymous lambda' called with unexpected argument 'nativeBuildInputs'
          # To add --print-targets support, since it may be years until a release
          # gnumake = prev.gnumake.overrideAttrs (oldAttrs: {
          #   patches = (oldAttrs.patches or [ ]) ++ [
          #     (prev.fetchpatch {
          #       name = "add-print-targets-support.patch";
          #       url = "https://git.savannah.gnu.org/cgit/make.git/patch/?id=31036e648f4a92ae0cce215eb3d60a1311a09c60";
          #       hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Replace with actual hash
          #     })
          #   ];
          # });

          linuxPackages_6_18 = prev.linuxPackages_6_18.extend (
            _lfinal: lprev: {
              xpadneo = lprev.xpadneo.overrideAttrs (old: {
                patches = (old.patches or [ ]) ++ [
                  (prev.fetchpatch {
                    url = "https://github.com/orderedstereographic/xpadneo/commit/233e1768fff838b70b9e942c4a5eee60e57c54d4.patch";
                    hash = "sha256-HL+SdL9kv3gBOdtsSyh49fwYgMCTyNkrFrT+Ig0ns7E=";
                    stripLen = 2;
                  })
                ];
              });
            }
          );
        }
      else
        { };

    # Modifies existing packages
    modifications = final: prev: {
      #atuin = prev.atuin.overrideAttrs (oldAttrs: {
      # This is probably ideal but the strip len doesn't seem to work
      # patches = oldAttrs.patches ++ [
      #   (prev.fetchpatch {
      #     url = "https://patch-diff.githubusercontent.com/raw/atuinsh/atuin/pull/2215.patch";
      #     sha256 = "sha256-LM5KDCSbWb3o06Y3b/vBOe4ylqF3Zs8YuE/4+CNEYgg=";
      #     stripLen = 2;
      #   })
      # ];
      #preBuild = prev.lib.optionalString prev.stdenv.isDarwin ''
      #  export RUSTFLAGS="-C link-arg=-Wl,-headerpad_max_install_names $RUSTFLAGS"
      #'';
      # FIXME: Get the patch working again
      #postPatch =
      #  let
      #    patch = prev.fetchurl {
      #      url = "https://patch-diff.githubusercontent.com/raw/atuinsh/atuin/pull/2215.patch";
      #      sha256 = "sha256-BuwmPS+xtzRM9b7+pGFGIEj2OsJlq4WvjxwQ0XFwUj8=";
      #    };
      #  in
      #  ''
      #    patch -p2 < ${patch}
      #  '';
      #});
      zsh-edit = prev.zsh-edit.overrideAttrs (oldAttrs: {
        src = prev.fetchFromGitHub {
          owner = "marlonrichert/";
          repo = "zsh-edit";
          rev = "113a0d53919c4866a1492574592eccafacdabe0b";
          sha256 = "sha256-l6qGSxj/lZ+jUaAFC2LYMwARwQpXmKdvii4jbVR1Kqo=";
        };
      });

    };
    unstable-packages = final: _prev: {
      unstable = import inputs.nixpkgs-unstable {
        system = final.stdenv.hostPlatform.system;
        config.allowUnfree = true;
        overlays = [
          # FIXME: waiting for pyghidra to be merged
          # (_final: prev: {
          #   ghidra = prev.ghidra.overrideAttrs (oldAttrs: {
          #     version = "11.3";
          #     passthru = oldAttrs.passthru // {
          #       distroPrefix = "ghidra_11.3_NIX";
          #     };
          #     nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [
          #       # prev.breakpointHook
          #     ];
          #     mitmCache = prev.gradle.fetchDeps {
          #       inherit (oldAttrs) pname;
          #       data = ./ghidra-deps.json;
          #     };
          #     #mitmCache = oldAttrs.mitmCache // {
          #     # updateScript = _final.runCommand "update-deps" { } ''
          #     #    ${oldAttrs.mitmCache.updateScript}
          #     #    cp deps.json /tmp/deps.json
          #     #  '';
          #     #};

          #     src = prev.fetchFromGitHub {
          #       owner = "NationalSecurityAgency";
          #       repo = "Ghidra";
          #       # late enough commit to  PyGhidra support
          #       rev = "7d5a514f25fe5bea52a0465c26ae5663855f79c9";
          #       hash = "sha256-PN5J2Wrr8RUF1UljG57bfw2lhlEqnmWwtZy5xQcrNsE=";
          #       # populate values that require us to use git. By doing this in postFetch we
          #       # can delete .git afterwards and maintain better reproducibility of the src.
          #       leaveDotGit = true;
          #       postFetch = ''
          #         cd "$out"
          #         git rev-parse HEAD > $out/COMMIT
          #         # 1970-Jan-01
          #         date -u -d "@$(git log -1 --pretty=%ct)" "+%Y-%b-%d" > $out/SOURCE_DATE_EPOCH
          #         # 19700101
          #         date -u -d "@$(git log -1 --pretty=%ct)" "+%Y%m%d" > $out/SOURCE_DATE_EPOCH_SHORT
          #         find "$out" -name .git -print0 | xargs -0 rm -rf
          #       '';
          #     };
          #     #preBuild =
          #     #  oldAttrs.postUnpack or ""
          #     #  + ''
          #     #    export JAVA_TOOL_OPTIONS="-Duser.home=$NIX_BUILD_TOP/home"
          #     #    gradle -I gradle/support/fetchDependencies.gradle
          #     #  '';
          #   });
          # })
        ];
      };
    };
  };
in
{
  default =
    final: prev:
    lib.attrNames overlays |> map (name: (overlays.${name} final prev)) |> lib.mergeAttrsList;
}
