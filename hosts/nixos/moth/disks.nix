{ lib, ... }:
{
  imports = (
    map lib.custom.relativeToRoot (
      # FIXME: This won't be needed once it becomes a module
      # but all other hosts need to be tweaked first
      [ "hosts/common/optional/disks.nix" ])
  );
  system.disks = {
    # FIXME: Auto-add the by-id prefix
    primary = "/dev/disk/by-id/mmc-SCA64G_0x56567305";
    swapSize = "2G";
    bootSize = "1G";
    raidLevel = 5;
    # FIXME: Auto-add the by-id prefix
    raidDisks = [
      "/dev/disk/by-id/nvme-EDILOCA_EN705_4TB_AA251809669"
      "/dev/disk/by-id/nvme-EDILOCA_EN705_4TB_AA251809987"
      "/dev/disk/by-id/nvme-EDILOCA_EN705_4TB_AA251809895"
      # FIXME: Uncomment after already created, to test adding drive to array
      # after initial install/disko run
      #"/dev/disk/by-id/nvme-EDILOCA_EN705_4TB_AA251809684"
    ];
    extraDisks = [
      {
        name = "encrypted-storage";
        uuid = "483ce643-d45f-4992-a23d-d502a5afe365";
      }
    ];
  };
}
