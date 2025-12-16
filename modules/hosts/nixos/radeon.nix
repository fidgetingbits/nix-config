# FIXME: This should use facter.json to determine this on the fly or something
# Also want to revisit the 'modules' naming, though we do need some sort of namespace soon
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.hardware.radeon;
in
{
  options.modules.hardware.radeon = {
    enable = lib.mkEnableOption "System has radeon card";
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.attrValues {
      inherit (pkgs)
        # Print all known information about all available OpenCL platforms and devices in the system
        clinfo
        # Top-like tool for viewing AMD Radeon GPU utilization
        radeontop
        # Application to read current clocks of AMD Radeon cards
        radeon-profile
        ;
      inherit (pkgs.rocmPackages)
        # ROCm Application for Reporting System Info
        rocminfo
        # ROCm Application for Reporting System Info
        # FIXME: currently problen in 7.x PR: https://github.com/NixOS/nixpkgs/pull/469378
        #amdsmi
        ;
    };
  };
}
