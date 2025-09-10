# FIXME:
# The cynthion repo doesn't seem to hold the file being looked for:
# [pid 28219] newfstatat(AT_FDCWD, "/nix/store/n0jjdrb8fzmr7nrx4w4lw5cchdw03209-python3.12-cynthion-0.1.8/lib/python3.12/site-packages/cynthion/assets/CynthionPlatformRev1D4/analyzer.bit", 0x7ffd48bc94c0, 0) = -1 ENOENT (No such file or directory)
# ```
# ❯ sudo cynthion update
# The Cynthion 'analyzer.bit' bitstream could not be located.
# ❯
# ❯ sudo cynthion update --mcu-firmware
# Updating device firmware with 13888 bytes...
# Operation complete!
# ❯ sudo cynthion update --bitstream
# The Cynthion 'analyzer.bit' bitstream could not be located.
# ```
# Seems these are generated at build time:
# https://github.com/greatscottgadgets/cynthion/pull/166

{ pkgs, ... }:
let
  prebuiltCynthion =
    (pkgs.unstable.cynthion.override {
      python3 = pkgs.unstable.python312;
    }).overridePythonAttrs
      (old: {
        # Dependencies for running 'make bitstreams' to install all assets/ are pre-built into the pypi package
        src = pkgs.fetchPypi {
          pname = "cynthion";
          version = "0.2.2";
          hash = "sha256-Nq+gg6dxKFEYU6fQIZPGUIOsZNtj51oy07CKpwomfSM=";
        };
        sourceRoot = null;
      });

  desktopItem = pkgs.makeDesktopItem {
    name = "Packetry";
    desktopName = "Packetry";
    comment = "Cynthion packet capture tool";
    exec = "${pkgs.packetry}/bin/packetry";
    icon = pkgs.fetchurl {
      url = "https://avatars.githubusercontent.com/u/5904722?s=48&v=4";
      sha256 = "sha256-G6TPHVedJaYBi4dgUmyUWE1wRyHSX6bE4/8GTjrZlf8=";
    };
    terminal = false;
    categories = [ "Network" ];
  };
in
{
  users.extraGroups.plugdev = { };
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "cynthion-udev-rules";
      # https://raw.githubusercontent.com/greatscottgadgets/cynthion/main/cynthion/python/assets/54-cynthion.rules
      text = ''
        SUBSYSTEM=="usb", ATTR{idVendor}=="1d50", ATTR{idProduct}=="615b", SYMLINK+="cynthion-%k", TAG+="uaccess"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1d50", ATTR{idProduct}=="615c", SYMLINK+="cynthion-apollo-%k", TAG+="uaccess"

        # Catchall for all pid.codes devices since some examples use various idProduct values
        SUBSYSTEM=="usb", ATTRS{idVendor}=="1209", TAG+="uaccess"
        #SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="000a", SYMLINK+="cynthion-tst-%k", TAG+="uaccess"
        #SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="000e", SYMLINK+="cynthion-example-%k", TAG+="uaccess"

        # Cynthion Hub Testing (emulated Genesys Logic Hub)
        SUBSYSTEM=="usb", ATTR{idVendor}=="05e3", ATTR{idProduct}=="0610", SYMLINK+="cynthion-hub-%k", TAG+="uaccess"
      '';
      destination = "/etc/udev/rules.d/10-cynthion.rules";
    })
  ];
  environment.systemPackages =
    builtins.attrValues {
      inherit (pkgs.unstable.python312Packages)
        facedancer
        greatfet
        kicad
        ;
    }
    ++ [
      prebuiltCynthion
      (pkgs.packetry.overrideAttrs (old: {
        extraInstallCommands = ''
          install -Dm644 ${desktopItem}/share/applications/packetry.desktop $out/share/applications/packetry.desktop
          substituteInPlace $out/share/applications/packetry.desktop \
            --replace "@out@" ${placeholder "out"}
        '';
      }))
    ];

}
