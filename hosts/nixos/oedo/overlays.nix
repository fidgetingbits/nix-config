{ inputs, ... }:
{
  nixpkgs.overlays = [
    (final: prev: {
      rocmPackages =
        let

          system = prev.stdenv.hostPlatform.system;
          # Fix a crash related to llama-server
          nixpkgs-rocm7 = (import inputs.nixpkgs-rocm7 { inherit system; });
        in
        nixpkgs-rocm7.rocmPackages;
    })
  ];
}
