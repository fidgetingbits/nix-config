{ ... }:
{
  system.disks = {
    primary = "/dev/nvme0n1";
    primaryLabel = "disk0";
    swapSize = "16G";
    bootSize = "1G";
    useLuks = true;
  };

}
