{ ... }:
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
      # FIXME: Uncomment after already created, to test adding drive to array
      # after initial install/disko run
      #"nvme-EDILOCA_EN705_4TB_AA251809684"
    ];
    extraDisks = [
      {
        name = "encrypted-storage";
        # NOTE: This UUID changes on a re-install
        uuid = "64ce59b9-756a-4897-b772-bd5d11f6839a";
      }
    ];
  };
}
