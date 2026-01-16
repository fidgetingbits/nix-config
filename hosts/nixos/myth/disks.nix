{ lib, ... }:
{
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
        path = "/dev/disk/by-id/md-name-any:raid5";
      }
    ];
  };
}
