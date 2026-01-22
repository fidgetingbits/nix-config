{
  description = "Fidgeting Nix";
  outputs =
    {
      self,
      nixpkgs,
      flake-parts,
      introdus,
      nix-secrets,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      inherit (nixpkgs) lib;
      namespace = "fidgetingbits"; # namespace for our custom modules. Snowfall lib style

      introdusLib = introdus.lib.mkIntrodusLib {
        lib = nixpkgs.lib;
        secrets = nix-secrets;
      };
      customLib = nixpkgs.lib.extend (
        self: super: {
          custom =
            introdusLib
            # NOTE: This overrides introdusLib entries with local changes via
            # '//' in case I want to test something
            // (import ./lib {
              inherit (nixpkgs) lib;
            });
        }
      );
      secrets = nix-secrets.mkSecrets nixpkgs customLib;

      mkHost = host: isDarwin: {
        ${host} =
          let
            func = if isDarwin then inputs.nix-darwin.lib.darwinSystem else lib.nixosSystem;
            systemFunc = func;
            # Propagate lib.custom into hm
            # see: https://github.com/nix-community/home-manager/pull/3454
          in
          systemFunc {
            specialArgs = rec {
              inherit
                inputs
                outputs
                namespace
                secrets
                ;
              lib = customLib;
              inherit isDarwin;
            };
            modules = [
              ./hosts/${if isDarwin then "darwin" else "nixos"}/${host}
            ];
          };
      };

      # FIXME: Move this
      # Bare minimum configuration for a host for faster initial install testing
      mkMinimalHost = host: {
        "${host}Minimal" = (
          lib.nixosSystem {
            # FIXME: This will break when we add aarch64, so set it via in hostSpec maybe?
            system = "x86_64-linux";
            # FIXME:This should merge with the above specialArgs
            specialArgs = {
              inherit
                inputs
                outputs
                namespace
                secrets
                ;
              lib = customLib;
              isDarwin = false;
            };
            modules = lib.flatten (
              [
                # FIXME: See if we can lift this from elsewhere now that we aren't standalone
                {
                  nixpkgs.overlays = [
                    (final: prev: {
                      unstable = import inputs.nixpkgs-unstable {
                        system = final.stdenv.hostPlatform.system;
                        config.allowUnfree = true;
                      };
                    })
                  ];
                }
                inputs.home-manager.nixosModules.home-manager
              ]
              ++
                # FIXME: If this moves to introdus, the hosts path need to become relative to the caller
                # not introdus
                (map customLib.custom.relativeToRoot [
                  # Minimal modules for quick setup
                  "modules/common/host-spec.nix"
                  "modules/hosts/nixos/disks.nix"
                  "modules/hosts/nixos/impermanence"

                  "hosts/nixos/${host}/host-spec.nix"
                  "hosts/nixos/${host}/disks.nix"

                  "hosts/common/optional/minimal-configuration.nix"
                ])
              ++ lib.optional (lib.pathExists ./hosts/nixos/${host}/facter.json) [
                inputs.nixos-facter-modules.nixosModules.facter
                {
                  config.facter.reportPath = (customLib.custom.relativeToRoot "hosts/nixos/${host}/facter.json");
                }
              ]
            );
          }
        );
      };

      mkHostConfigs =
        hosts: isDarwin:
        lib.foldl (acc: set: acc // set) { } (
          (lib.map (host: mkHost host isDarwin) hosts)
          ++ (lib.map (host: mkMinimalHost host) (lib.filter (h: h != "iso") hosts))
        );
      readHosts = folder: lib.attrNames (builtins.readDir ./hosts/${folder});
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      flake = {
        overlays = (
          import ./overlays {
            inherit inputs lib secrets;
          }
        );
        nixosConfigurations = mkHostConfigs (readHosts "nixos") false;
        darwinConfigurations = mkHostConfigs (readHosts "darwin") true;
      };
      systems = [
        "x86_64-linux"
      ];
      perSystem =
        { system, ... }:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              introdus.overlays.default
              self.overlays.default
            ];
          };
          formatter = inputs.introdus.formatter.${system};
        in
        rec {
          _module.args.pkgs = pkgs;
          packages = lib.packagesFromDirectoryRecursive {
            callPackage = lib.callPackageWith pkgs;
            directory = ./pkgs;
          };
          # FIXME: There might be a better way to auto-integrate the introdus formatter
          checks = import ./checks {
            inherit
              inputs
              pkgs
              system
              lib
              formatter
              ;
          };
          inherit formatter;
          devShells = import ./shell.nix {
            inherit
              checks
              inputs
              system
              pkgs
              lib
              ;
          };
        };
    };

  inputs = {

    #################### Core Nix Sources ####################
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    #nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-unstable = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #################### Utilities ####################

    # Secret management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Modern nixos-hardware alternative
    nixos-facter-modules.url = "github:nix-community/nixos-facter-modules";
    nixos-hardware = {
      url = "github:nixos/nixos-hardware";
    };

    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-sweep = {
      url = "github:jzbor/nix-sweep/v0.7.0";
      # inputs.nixpkgs.follows = "nixpkgs";
    };

    # Allows most third-party vscode extensions
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Ad-blocking host list
    adblock-hosts = {
      url = "github:StevenBlack/hosts";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvirt = {
      url = "https://flakehub.com/f/AshleyYakeley/NixVirt/*.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    firefox2nix = {
      url = "git+https://git.sr.ht/~rycee/mozilla-addons-to-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    talon-nix = {
      url = "github:fidgetingbits/talon-nix?ref=overrides";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #################### Ricing ####################
    stylix = {
      url = "github:danth/stylix/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    silentSDDM = {
      url = "github:uiriansan/SilentSDDM";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #################### Personal ####################
    nix-secrets = {
      url = "git+ssh://git@gitlab.com/fidgetingbits/nix-secrets.git?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixcats-flake = {
      url = "github:fidgetingbits/neovim?ref=main&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nix-assets = {
      url = "github:fidgetingbits/nix-assets?shallow=1";
    };
    pwndbg.url = "github:pwndbg/pwndbg";

    introdus = {
      # url = "git+ssh://git@codeberg.org/fidgetingbits/introdus?shallow=1&ref=aa";
      url = "path:///home/aa/dev/nix/introdus/aa";
    };
  };
}
