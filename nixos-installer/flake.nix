{
  description = "Minimal NixOS configuration for bootstrapping systems";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
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
        name: disk: swapSize: impermanence:
        (nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs outputs;
            lib = nixpkgs.lib.extend (self: super: { custom = import ../lib { inherit (nixpkgs) lib; }; });

          };
          modules = [
            inputs.disko.nixosModules.disko
            ../hosts/common/disks/btrfs-luks-impermanence-disko.nix
            {
              _module.args = {
                inherit disk;
                withSwap = swapSize > 0;
                swapSize = builtins.toString swapSize;
              };
            }
            ./minimal-configuration.nix
            ../hosts/nixos/${name}/hardware-configuration.nix
            ../modules/hosts/nixos/impermanence
            {
              networking.hostName = name;
              system.impermanence.enable = impermanence;
            }
          ];
        });
    in
    {
      nixosConfigurations = {
        oedo = newConfig "oedo" "/dev/nvme0n1" 64 true;
        ooze = newConfig "ooze" "/dev/nvme0n1" 64 true;
        #onyx = newConfig "onyx" "/dev/nvme0n1" 64 false;
        okra = newConfig "okra" "/dev/vda" 0 true;
      };
    };
}
