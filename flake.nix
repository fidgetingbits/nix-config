{
  description = "Fidgetingbits Nix Flake";
  outputs =
    {
      self,
      nixpkgs,
      flake-parts,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      inherit (nixpkgs) lib;

      mkHost = host: isDarwin: {
        ${host} =
          let
            func = if isDarwin then inputs.nix-darwin.lib.darwinSystem else lib.nixosSystem;
            systemFunc = func;
          in
          systemFunc {
            specialArgs = {
              inherit inputs outputs;
              # Propagate lib.custom into hm
              # see: https://github.com/nix-community/home-manager/pull/3454
              lib = nixpkgs.lib.extend (self: super: { custom = import ./lib { inherit (nixpkgs) lib; }; });
              inherit isDarwin;
            };
            modules = [ ./hosts/${if isDarwin then "darwin" else "nixos"}/${host} ];
          };
      };
      mkHostConfigs =
        hosts: isDarwin: lib.foldl (acc: set: acc // set) { } (lib.map (host: mkHost host isDarwin) hosts);
      readHosts = folder: lib.attrNames (builtins.readDir ./hosts/${folder});
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      flake = {
        overlays = import ./overlays { inherit inputs lib; };
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
            overlays = [ self.overlays.default ];
          };
        in
        rec {
          packages = lib.packagesFromDirectoryRecursive {
            callPackage = lib.callPackageWith pkgs;
            directory = ./pkgs/common;
          };
          checks = import ./checks { inherit inputs pkgs system; };
          formatter = pkgs.nixfmt;
          devShells = import ./shell.nix {
            inherit
              checks
              inputs
              system
              pkgs
              ;
          };
        };
    };

  inputs = {

    #################### Core Nix Sources ####################
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    #nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      #inputs.nixpkgs.follows = "nixpkgs";
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
      # FIXME(sddm): Pinned because of https://github.com/uiriansan/SilentSDDM/issues/55
      url = "github:uiriansan/SilentSDDM?rev=cfb0e3eb380cfc61e73ad4bce90e4dcbb9400291";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #################### Personal ####################
    nix-secrets = {
      url = "git+ssh://git@gitlab.com/fidgetingbits/nix-secrets.git?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    #nixvim-flake = {
    #  url = "git+ssh://git@gitlab.com/fidgetingbits/nixvim-flake.git?shallow=1";
    #  inputs.nixpkgs.follows = "nixpkgs";
    #};
    nixcats-flake = {
      url = "github:fidgetingbits/neovim?shallow=1?ref=main&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nix-assets = {
      url = "github:fidgetingbits/nix-assets?shallow=1";
    };

    #    introdus = {
    #      url = "github:emergentmind/introdus?shallow=1";
    #    };
  };
}
