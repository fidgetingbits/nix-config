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
              # FIXME: This doesn't account for all disk possibilities we have atm I think
              diskFile = (
                if opts ? diskFile then
                  opts.diskFile
                else if opts.luks then
                  ../hosts/common/disks/btrfs-luks-impermanence-disko.nix
                else
                  ../hosts/common/disks/btrfs-impermanence-disko.nix
              );
              # FIXME: This is a hack for now to and we'll replace
              diskConfig = (if opts ? diskConfig then opts.diskConfig else { });
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

              inputs.disko.nixosModules.disko
              diskFile
              {
                _module.args =
                  let
                    swapSize = if opts ? swapSize then opts.swapSize else 0;
                    disk = if opts ? disk then opts.disk else "";
                  in
                  {
                    inherit disk;
                    withSwap = swapSize > 0;
                    swapSize = builtins.toString swapSize;
                  };
              }
              # This is options we set for the disks.nix file, which eventually will replace the above
              diskConfig

              ./minimal-configuration.nix
              {
                hostSpec.username = user;
                hostSpec.primaryUsername = user;
              }
              ../modules/hosts/nixos/impermanence
              {
                networking.hostName = opts.name;
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
          disk = "/dev/nvme0n1";
          swapSize = 64;
          impermanence = true;
          luks = true;
          facter = false;
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
          disk = "/dev/vda";
          impermanence = true;
          luks = true;
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
          diskFile = ../hosts/nixos/myth/disko.nix;
          impermanence = true;
          facter = true;
          user = "admin";
        };

        moth = newConfig {
          name = "moth";
          user = "aa";
          impermanence = true;
          facter = true;
          diskFile = ../hosts/common/optional/disks.nix;
          diskConfig = import ../hosts/nixos/moth/disks.nix;
        };

      };
    };
}
