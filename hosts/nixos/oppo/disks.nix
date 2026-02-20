{ ... }:
{
  system.disks = {
    primary = "/dev/nvme0n1";
    primaryDiskoLabel = "vda"; # FIXME: change this if you ever rebuild, a symptom of old files
    swapSize = "16G";
    bootSize = "512M";
    luks.enable = true;
  };
}
