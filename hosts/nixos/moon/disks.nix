{ ... }:
{
  system.disks = {
    primary = "/dev/disk/by-id/nvme-512GB_SSD_MQ26W40700128";
    primaryDiskoLabel = "disk0";
    swapSize = "16G";
    bootSize = "512M";
    luks.enable = false;
  };
}
