{ inputs, ... }:
{
  imports = [
    inputs.nixos-hardware-oedo.nixosModules.dell-precision-5570
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia-sync
  ];
}
