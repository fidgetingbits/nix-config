{
  inputs,
  lib,
  secrets,
  ...
}:
let
  overlays = {
    # Add custom packages
    additions =
      final: prev:
      let
        system = final.stdenv.hostPlatform.system;
      in
      (
        prev.lib.packagesFromDirectoryRecursive {
          callPackage = prev.lib.callPackageWith final;
          directory = ../pkgs;
        }
        # Any nixpkgs PRs that aren't upstream yet
        // {
        }
      )
      # Other external inputs
      // {
        #neovim = inputs.nixvim-flake.packages.${system}.default;
        neovim = inputs.nixcats-flake.packages.${system}.default;
        nixcats = inputs.nixcats-flake.packages.${system}.default;
        nix-sweep = inputs.nix-sweep.packages.${system}.default;
        pwndbg = inputs.pwndbg.packages.${system}.default;
      };

    linuxModifications =
      final: prev:
      lib.optionalAttrs prev.stdenv.isLinux ({
        # FIXME: note why I overlayed this
        zsh-edit = prev.zsh-edit.overrideAttrs (oldAttrs: {
          src = prev.fetchFromGitHub {
            owner = "marlonrichert/";
            repo = "zsh-edit";
            rev = "113a0d53919c4866a1492574592eccafacdabe0b";
            sha256 = "sha256-l6qGSxj/lZ+jUaAFC2LYMwARwQpXmKdvii4jbVR1Kqo=";
          };
        });

        # FIXME: patch doesn't apply cleanly..
        # add --print-targets support, since it may be years until a release
        # gnumake = prev.gnumake.overrideAttrs (oldAttrs: {
        #   patches = [
        #     (builtins.fetchurl {
        #       url = "https://git.savannah.gnu.org/cgit/make.git/patch/?id=31036e648f4a92ae0cce215eb3d60a1311a09c60";
        #       sha256 = "sha256:1jb9arwzpr1qjan23xrggyhp6hppwyc0x8k3wjwvc1a4d9fc5a47";
        #     })
        #   ]
        #   ++ (oldAttrs.patches or [ ]);
        # });
        talon-unwrapped =
          let
            # Pull out the 0.4.0-411-g6d1e version part from
            # talon-linux-115-0.4.0-411-g6d1e.tar.xz in beta-url
            beta = secrets.talon-linux-beta;
            version = prev.lib.elemAt (prev.lib.match ".*talon-linux-[0-9]+-(.*).tar.xz" beta.url) 0;
          in
          prev.talon-unwrapped.overrideAttrs (oldAttrs: {
            inherit version;
            src = prev.fetchurl {
              inherit (beta) url sha256;
            };
          });
      });

    # Override unstable entries exposed via pkgs.unstable
    unstable-packages = final: _prev: {
      unstable = import inputs.nixpkgs-unstable {
        system = final.stdenv.hostPlatform.system;
        config.allowUnfree = true;
        overlays = [
        ];
      };
    };
  };
in
{
  default =
    final: prev:
    lib.attrNames overlays
    |> map (name: (overlays.${name} final prev))
    # nixfmt hack
    |> lib.mergeAttrsList;
}
