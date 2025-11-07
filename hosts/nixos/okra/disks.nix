{ lib, ... }:
{
  imports = (
    map lib.custom.relativeToRoot (
      # FIXME: This won't be needed once it becomes a module
      # but all other hosts need to be tweaked first
      [ "hosts/common/optional/disks.nix" ])
  );
  system.disks = {
    primary = "/dev/vda";
    swapSize = "2G";
  };
}
