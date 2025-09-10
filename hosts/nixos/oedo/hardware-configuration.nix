{ inputs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.dell-precision-5570
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia-sync
  ];
}
