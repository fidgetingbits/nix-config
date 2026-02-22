{ ... }:
{
  system.disks = {
    primary = "/dev/disk/by-id/nvme-CT2000T705SSD3_2513E9B23F9B";
    primaryDiskoLabel = "vda"; # FIXME: change this if you ever rebuild, a symptom of old files
    swapSize = "16G";
    bootSize = "512M";
    luks.enable = true;
  };
}
