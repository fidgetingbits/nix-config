{
  description = "Minimal NixOS configuration for bootstrapping systems";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    disko.url = "github:nix-community/disko";
    impermanence.url = "github:nix-community/impermanence";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    nixos-hardware-oedo = {
      url = "github:fidgetingbits/nixos-hardware?ref=dell-precision-5570";
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      inherit (self) outputs;

      # This mkHost is way better: https://github.com/linyinfeng/dotfiles/blob/8785bdb188504cfda3daae9c3f70a6935e35c4df/flake/hosts.nix#L358
      newConfig =
        opts:
        #name: disk: swapSize: impermanence: luks:
        (nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs outputs;
            lib = nixpkgs.lib.extend (self: super: { custom = import ../lib { inherit (nixpkgs) lib; }; });

          };
          modules =
            let
            in
            [
              (
                if opts.luks then
                  ../hosts/common/disks/btrfs-luks-impermanence-disko.nix
                else
                  ../hosts/common/disks/btrfs-impermanence-disko.nix
              )
              inputs.disko.nixosModules.disko
              {
                _module.args = {
                  inherit (opts.disk) ;
                  withSwap = opts.swapSize > 0;
                  swapSize = builtins.toString opts.swapSize;
                };
              }
              ./minimal-configuration.nix
              ../hosts/nixos/${opts.name}/hardware-configuration.nix
              ../modules/hosts/nixos/impermanence
              {
                networking.hostName = opts.name;
                system.impermanence.enable = opts.impermanence;
              }
            ];
        });
    in
    {
      nixosConfigurations = {
        #
        # Local network
        #

        # physical machines
        oedo = newConfig {
          name = "oedo";
          disk = "/dev/nvme0n1";
          swapSize = 64;
          impermanence = true;
          luks = true;
        };
        ooze = newConfig {
          name = "ooze";
          disk = "/dev/nvme0n1";
          swapSize = 64;
          impermanence = true;
          luks = true;
        };
        oppo = newConfig {
          name = "oppo";
          disk = "/dev/nvme0n1";
          swapSize = 64;
          impermanence = true;
          luks = true;
        };
        # FIXME: Double check this when framework arrives
        #onyx = newConfig { name = "onyx"; disk = "/dev/nvme0n1"; swapSize = 98; impermanence = true; luks = true; };

        # virtual machines
        okra = newConfig {
          name = "okra";
          disk = "/dev/vda";
          swapSize = 0;
          impermanence = true;
          luks = true;
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
        };
      };
    };
}
