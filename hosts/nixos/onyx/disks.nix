{ lib, ... }:
{
  # FIXME: Old stuff to remove on rebuild
  # This is nvme0n1p3, was used for encrypted swap
  #  boot.initrd.luks.devices."luks-e2232963-327f-4833-9bcc-5e5a8dae9551".device =
  #    "/dev/disk/by-uuid/e2232963-327f-4833-9bcc-5e5a8dae9551";
  #  boot.initrd.luks.devices."luks-e2232963-327f-4833-9bcc-5e5a8dae9551".keyFile =
  #    "/crypto_keyfile.bin";
  # This is nvme0n1p0, mounted to root
  boot.initrd.luks.devices."luks-27824da5-5b37-4cf4-ba27-9901484ea742".device =
    "/dev/disk/by-uuid/27824da5-5b37-4cf4-ba27-9901484ea742";

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/f2daf8ee-c391-4e54-b387-93db4f242c8b";
    fsType = lib.mkForce "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/AB1A-D21D";
    fsType = "vfat";
  };
  # END OF OLD STUFF

  system.disks = {
    enable = lib.mkForce false; # We don't use disko yet
    primary = "/dev/nvme0n1";
    primaryLabel = "vda"; # FIXME: change this if you ever rebuild, a symptom of old files
    swapSize = "16G";
    bootSize = "512M";
    useLuks = true;
  };

}
