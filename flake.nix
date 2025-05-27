{
  description = "Fidgetingbits Nix Flake";
  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      inherit (self) outputs;
      inherit (nixpkgs) lib;

      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

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
    {
      overlays = import ./overlays { inherit inputs; };
      nixosConfigurations = mkHostConfigs (readHosts "nixos") false;
      darwinConfigurations = mkHostConfigs (readHosts "darwin") true;
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
      devShells = forAllSystems (
        system:
        import ./shell.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          checks = self.checks.${system};
        }
      );
      checks = forAllSystems (
        system:
        import ./checks {
          inherit inputs system;
          pkgs = nixpkgs.legacyPackages.${system};
        }
      );
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in
        lib.packagesFromDirectoryRecursive {
          callPackage = lib.callPackageWith pkgs;
          directory = ./pkgs/common;
        }
        // {
          ghidra = pkgs.unstable.ghidra;
        }
      );
    };

  inputs = {
    #################### Official NixOS / Nix-Darwin / HM Package Sources ####################
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-bindiff.url = "github:pluiedev/nixpkgs/ff07c69d5490428597cc4ff30553fdb88d6bf6be";

    nixpkgs-darwin.url = "github:nixos/nixpkgs/nixpkgs-25.05-darwin";
    nix-darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-unstable = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.3.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:nixos/nixos-hardware";

    nixos-hardware-oedo = {
      url = "github:fidgetingbits/nixos-hardware?ref=dell-precision-5570";
    };

    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvirt = {
      url = "https://flakehub.com/f/AshleyYakeley/NixVirt/*.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Theming
    stylix = {
      url = "github:danth/stylix/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #################### Utilities ####################
    # HM module to fix up launchers for nix apps on darwin
    mac-app-util.url = "github:hraban/mac-app-util";

    # Secret management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Allows most third-party vscode extensions
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

    # firefox is broken on darwin
    nixpkgs-firefox-darwin.url = "github:bandithedoge/nixpkgs-firefox-darwin";

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    talon-nix = {
      url = "github:fidgetingbits/talon-nix?ref=overrides";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    unblob = {
      url = "github:onekey-sec/unblob";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #################### Personal Repositories ####################
    nix-secrets = {
      url = "git+ssh://git@gitlab.com/fidgetingbits/nix-secrets.git?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim-flake.url = "git+ssh://git@gitlab.com/fidgetingbits/nixvim-flake.git?shallow=1";
    #nixvim-flake.url = "path:/home/aa/dev/nix/nixvim-flake";
  };
}
