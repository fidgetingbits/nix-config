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
  # cynthion is marked broken for newer amaranth and there is also a dependency conflict between cynthion and luna-usb
  customAmaranth = pkgs.unstable.python3Packages.amaranth.overridePythonAttrs (old: {
    version = "0.4.1";
    src = pkgs.fetchFromGitHub {
      owner = "amaranth-lang";
      repo = "amaranth";
      rev = "v0.4.1";
      hash = "sha256-XL5S7/Utfg83DLIBGBDWYoQnRZaFE11Wy+XXbimu3Q8=";
    };
    pyproject = true;
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.python3Packages.setuptools ];
    postPatch = "";
  });

  prebuiltCynthion =
    (pkgs.unstable.cynthion.override {
      python3 = pkgs.unstable.python3.override {
        packageOverrides = self: super: {
          amaranth = customAmaranth;
          luna-usb = super.luna-usb.overridePythonAttrs (old: {
            propagatedBuildInputs =
              builtins.filter (dep: (dep.pname or "") != "amaranth") (old.propagatedBuildInputs or [ ])
              ++ [ self.amaranth ];
          });
        };
      };
    }).overridePythonAttrs
      (old: {
        # Dependencies for running 'make bitstreams' to install all assets/ are pre-built into the pypi package
        src = pkgs.fetchPypi {
          pname = "cynthion";
          version = "0.1.8";
          hash = "sha256-eFPyoSs1NxzyBBV/7MAuEbo+cPL3jBg4DPVwift6dPw=";
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

        # Catchall for all pid.codes devices since some examples use various idProduc values
        SUBSYSTEM=="usb", ATTRS{idVendor}=="1209", TAG+="uaccess"
        #SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="000a", SYMLINK+="cynthion-tst-%k", TAG+="uaccess"
        #SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="000e", SYMLINK+="cynthion-example-%k", TAG+="uaccess"

        #
      '';
      destination = "/etc/udev/rules.d/10-cynthion.rules";
    })
  ];
  environment.systemPackages =
    builtins.attrValues {
      inherit (pkgs.unstable.python3Packages)
        facedancer
        greatfet
        ;
    }
    ++ [
      #customCynthion
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
