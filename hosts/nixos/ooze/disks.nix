{ lib, ... }:
{
  imports = (
    map lib.custom.relativeToRoot (
      # FIXME: This won't be needed once it becomes a module
      # but all other hosts need to be tweaked first
      [ "hosts/common/optional/disks.nix" ])
  );
  system.disks = {
    primary = "/dev/nvme0n1";
    primaryLabel = "vda"; # FIXME: change this if you ever rebuild, a symptom of old files
    swapSize = "16G";
    bootSize = "512M";
    useLuks = true;
  };
}
