{ ... }:
{
  system.disks = {
    primary = "/dev/disk/by-id/nvme-MSI_M390_1TB_511231213261000483";
    primaryDiskoLabel = "vda"; # FIXME: change this if you ever rebuild, a symptom of old files
    swapSize = "16G";
    bootSize = "512M";
    luks.enable = true;
  };
}
