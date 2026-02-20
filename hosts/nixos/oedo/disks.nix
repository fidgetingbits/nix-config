{ ... }:
{
  system.disks = {
    primary = "/dev/nvme-CT2000P310SSD8_2522509359B2";
    primaryDiskoLabel = "disk0";
    swapSize = "16G";
    bootSize = "1G";
    luks.enable = true;
  };
}
