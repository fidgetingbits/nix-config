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
          inherit inputs;
          inherit system;
          unstable = inputs.nixpkgs-unstable.legacyPackages.${system};
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
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    #nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";

    # orby is gone
    #nixpkgs-darwin.url = "github:nixos/nixpkgs/nixpkgs-25.05-darwin";
    #nix-darwin = {
    #  url = "github:lnl7/nix-darwin";
    #  inputs.nixpkgs.follows = "nixpkgs-darwin";
    #};

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

    #lanzaboote = {
    #  url = "github:nix-community/lanzaboote/v0.3.0";
    #  inputs.nixpkgs.follows = "nixpkgs";
    #};

    nixos-hardware = {
      url = "github:nixos/nixos-hardware";
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
    silentSDDM = {
      url = "github:uiriansan/SilentSDDM";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #################### Utilities ####################
    # HM module to fix up launchers for nix apps on darwin
    #mac-app-util.url = "github:hraban/mac-app-util";

    # Secret management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
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

    # firefox is broken on darwin
    #nixpkgs-firefox-darwin = {
    #  url = "github:bandithedoge/nixpkgs-firefox-darwin";
    #  inputs.nixpkgs.follows = "nixpkgs";
    #};
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    firefox2nix = {
      url = "git+https://git.sr.ht/~rycee/mozilla-addons-to-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    talon-nix = {
      url = "github:fidgetingbits/talon-nix?ref=overrides";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #################### Personal Repositories ####################
    nix-secrets = {
      url = "git+ssh://git@gitlab.com/fidgetingbits/nix-secrets.git?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    #nixvim-flake = {
    #  url = "git+ssh://git@gitlab.com/fidgetingbits/nixvim-flake.git?shallow=1";
    #  inputs.nixpkgs.follows = "nixpkgs";
    #};
    nixcats-flake = {
      url = "github:fidgetingbits/neovim?shallow=1?ref=main";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nix-assets = {
      url = "github:fidgetingbits/nix-assets";
    };
    # Modern nixos-hardware alternative
    nixos-facter-modules.url = "github:nix-community/nixos-facter-modules";
  };
}
