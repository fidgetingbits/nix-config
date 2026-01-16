{ lib, ... }:
{
  system.disks = {
    primary = "/dev/disk/by-id/mmc-SCA64G_0x56567305";
    swapSize = "2G";
    bootSize = "1G";
    raidLevel = 5;
    raidDisks = lib.map (d: "/dev/disk/by-id/${d}") [
      "nvme-EDILOCA_EN705_4TB_AA251809669"
      "nvme-EDILOCA_EN705_4TB_AA251809987"
      "nvme-EDILOCA_EN705_4TB_AA251809895"
      "nvme-EDILOCA_EN705_4TB_AA251809684"
    ];
    #extraDisks = [
    #  {
    #    name = "encrypted-storage";
    #    path = "/dev/disk/by-id/md-name-any:raid5";
    #  }
    #];
  };
}
