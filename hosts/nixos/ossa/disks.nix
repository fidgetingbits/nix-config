{ ... }:
{
  system.disks = {
    primary = "/dev/nvme0n1";
    primaryDiskoLabel = "disk0";
    swapSize = "16G";
    bootSize = "1G";
    luks.enable = true;
  };
}
