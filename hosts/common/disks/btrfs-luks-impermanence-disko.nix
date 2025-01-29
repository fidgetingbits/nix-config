# NOTE: ... is needed because disko passes diskoFile
{
  lib,
  pkgs,
  disk ? "/dev/vda",
  withSwap ? true,
  swapSize,
  config,
  ...
}:
{
  disko.devices = {
    disk = {
      vda = {
        type = "disk";
        device = disk;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "defaults" ];
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "encrypted-nixos";
                passwordFile = "/tmp/disko-password"; # populated by bootstrap-nixos.sh
                settings = {
                  allowDiscards = true;
                  # https://github.com/hmajid2301/dotfiles/blob/a0b511c79b11d9b4afe2a5e2b7eedb2af23e288f/systems/x86_64-linux/framework/disks.nix#L36
                  crypttabExtraOpts = [
                    "fido2-device=auto"
                    "token-timeout=10"
                  ];
                };
                # From mic92 demo: https://github.com/Mic92/disko-yubikey-demo/blob/main/installed.nix
                # postCreateHook = ''
                #   PASSWORD=$(cat /tmp/disko-password) ${config.systemd.package}/bin/systemd-cryptenroll --fido2-device=auto ${disk}
                # '';
                # Subvolumes must set a mountpoint in order to be mounted, unless their parent is mounted
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ];
                  subvolumes = {
                    "@root" = {
                      mountpoint = "/";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                    "@persist" = {
                      mountpoint = "${config.hostSpec.persistFolder}";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                    "@nix" = {
                      mountpoint = "/nix";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                    "@swap" = lib.mkIf withSwap {
                      mountpoint = "/.swapvol";
                      swap.swapfile.size = "${swapSize}G";
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };

  environment.systemPackages = [
    pkgs.yubikey-manager # For luks fido2 enrollment before full install
  ];
}
