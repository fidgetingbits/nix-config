{ lib, ... }:
{
  imports = (
    map lib.custom.relativeToRoot (
      # FIXME: This won't be needed once it becomes a module
      # but all other hosts need to be tweaked first
      [ "hosts/common/optional/disks.nix" ])
  );
  system.disks = {
    primary = "/dev/disk/by-id/mmc-SCA64G_0x56567305";
    swapSize = "2G";
    bootSize = "512M";
    raidLevel = 5;
    raidDisks = lib.map (d: "/dev/disk/by-id/${d}") [
      "nvme-CT2000P3PSSD8_2504E9A1BF6E"
      "nvme-CT2000P3PSSD8_2504E9A1BF62"
      "nvme-CT2000P3PSSD8_2504E9A1BF79"
    ];
    extraDisks = [
      {
        name = "encrypted-storage";
        # NOTE: This UUID changes on a re-install
        uuid = "ff3207ca-0af8-4dc3-a21f-4ec815b57c56";
      }
    ];
  };
}
