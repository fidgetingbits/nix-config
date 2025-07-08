{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "vmd"
    "nvme"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/f2daf8ee-c391-4e54-b387-93db4f242c8b";
    fsType = lib.mkForce "ext4";
  };

  boot.initrd.luks.devices."luks-27824da5-5b37-4cf4-ba27-9901484ea742".device =
    "/dev/disk/by-uuid/27824da5-5b37-4cf4-ba27-9901484ea742";

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/AB1A-D21D";
    fsType = "vfat";
  };

  #swapDevices = [ { device = "/dev/disk/by-uuid/eabbf1b6-0c66-45fb-b064-c6ac88443a45"; } ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
}
