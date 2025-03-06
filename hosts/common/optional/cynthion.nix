{ pkgs, ... }:
let
  # cynthion is marked broken for newer amaranth and there is also a dependency conflict between cynthion and luna-usb
  customAmaranth = pkgs.unstable.python312Packages.amaranth.overridePythonAttrs (old: {
    version = "0.4.1";
    src = pkgs.fetchFromGitHub {
      owner = "amaranth-lang";
      repo = "amaranth";
      rev = "v0.4.1";
      hash = "sha256-XL5S7/Utfg83DLIBGBDWYoQnRZaFE11Wy+XXbimu3Q8=";
    };
    pyproject = true;
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.python312Packages.setuptools ];
    postPatch = "";
  });
  # Override cynthion to use our custom luna-usb and amaranth
  customCynthion = pkgs.unstable.cynthion.override {
    python3 = pkgs.unstable.python312.override {
      packageOverrides = self: super: {
        amaranth = customAmaranth;
        luna-usb = super.luna-usb.overridePythonAttrs (old: {
          propagatedBuildInputs =
            builtins.filter (dep: (dep.pname or "") != "amaranth") (old.propagatedBuildInputs or [ ])
            ++ [ self.amaranth ];
        });
      };
    };
  };
in
{
  users.extraGroups.plugdev = { };
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "cynthion-udev-rules";
      text = ''
        SUBSYSTEM=="usb", ATTRS{idVendor}=="1d50", ATTRS{idProduct}=="615b", TAG+="uaccess" MODE="660", GROUP="plugdev"
      '';
      destination = "/etc/udev/rules.d/10-cynthion.rules";
    })
  ];
  environment.systemPackages =
    builtins.attrValues {
      inherit (pkgs.unstable.python312Packages)
        facedancer
        greatfet
        ;
      inherit (pkgs)
        packetry
        ; # cynthion capture tool
    }
    ++ [
      customCynthion
    ];
}
