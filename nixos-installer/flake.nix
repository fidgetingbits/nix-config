{
  description = "Minimal NixOS configuration for bootstrapping systems";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
    impermanence.url = "github:nix-community/impermanence";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    nixos-facter-modules.url = "github:nix-community/nixos-facter-modules";
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }@inputs:
    let
      inherit (self) outputs;

      # This mkHost is way better: https://github.com/linyinfeng/dotfiles/blob/8785bdb188504cfda3daae9c3f70a6935e35c4df/flake/hosts.nix#L358
      newConfig =
        opts:
        (nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs outputs;
            isDarwin = false;
            lib = nixpkgs.lib.extend (self: super: { custom = import ../lib { inherit (nixpkgs) lib; }; });
          };
          modules =
            # FIXME: The default user should come from an external source once we make this a lib
            let
              user = if opts ? user then opts.user else "aa";
            in
            [
              # Needed because we use unstable nix sometimes
              {
                nixpkgs.overlays = [
                  (final: prev: {
                    unstable = import inputs.nixpkgs-unstable {
                      inherit (final) system;
                      config.allowUnfree = true;
                    };
                  })
                ];
              }

              # Disk definitions for this host
              ../hosts/nixos/${opts.name}/disks.nix

              ./minimal-configuration.nix
              {
                hostSpec.username = user;
                hostSpec.primaryUsername = user;
              }
              ../modules/hosts/nixos/impermanence
              {
                networking.hostName = opts.name;
                # FIXME: we can pull this out of the disks config now once
                # everything is converted
                system.impermanence.enable = opts.impermanence;
              }

            ]
            ++ (
              if opts.facter then
                [
                  inputs.nixos-facter-modules.nixosModules.facter
                  {
                    config.facter.reportPath = ../hosts/nixos/${opts.name}/facter.json;
                  }
                ]
              else
                [
                  ../hosts/nixos/${opts.name}/hardware-configuration.nix
                ]
            );
        });
    in
    {
      # FIXME: This should become a function or something that just generates it and is passed remotely
      nixosConfigurations = {
        #
        # Local network
        #

        # physical machines
        oedo = newConfig {
          name = "oedo";
          swapSize = 64;
          impermanence = true;
          luks = true;
          facter = true;
          diskConfig = import ../hosts/nixos/oedo/disks.nix;
        };
        ooze = newConfig {
          name = "ooze";
          disk = "/dev/nvme0n1";
          swapSize = 64;
          impermanence = true;
          luks = true;
          facter = false;
        };

        oppo = newConfig {
          name = "oppo";
          disk = "/dev/nvme0n1";
          swapSize = 64;
          impermanence = true;
          luks = true;
          facter = false;
        };

        # FIXME: Double check this when framework arrives
        #onyx = newConfig { name = "onyx"; disk = "/dev/nvme0n1"; swapSize = 98; impermanence = true; luks = true; };

        # virtual machines
        okra = newConfig {
          name = "okra";
          impermanence = true;
          facter = false;
        };

        #
        # Remotely managed
        #

        # physical machines
        moon = newConfig {
          name = "moon";
          disk = "/dev/nvme0n1";
          swapSize = 16;
          impermanence = true;
          luks = false;
          facter = true;
          user = "admin";
        };

        myth = newConfig {
          name = "myth";
          impermanence = true;
          facter = true;
          user = "admin";
          diskConfig = import ../hosts/nixos/myth/disks.nix;
        };

        moth = newConfig {
          name = "moth";
          user = "aa";
          impermanence = true;
          facter = true;
          diskConfig = import ../hosts/nixos/moth/disks.nix;
        };

        # virtual machines

        maze = newConfig {
          name = "maze";
          impermanence = true;
          facter = true;
          user = "aa";
          diskConfig = import ../hosts/nixos/maze/disks.nix;
        };
      };
    };
}
