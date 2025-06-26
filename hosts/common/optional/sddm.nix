{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  sddm-theme = inputs.silentSDDM.packages.${pkgs.system}.default.override {
    theme = "rei";
  };
in
{
  security.pam.services.sddm.enableGnomeKeyring = true;
  environment.systemPackages = [ sddm-theme ];
  qt.enable = true;
  services.displayManager.sddm = {
    package = pkgs.kdePackages.sddm; # use qt6 version of sddm
    enable = true;
    theme = sddm-theme.pname;
    extraPackages = sddm-theme.propagatedBuildInputs;
    settings = {
      General =
        let
          greeterEnvVars = lib.flatten (
            [
              "QML2_IMPORT_PATH=${sddm-theme}/share/sddm/themes/${sddm-theme.pname}/components/"
              "QT_IM_MODULE=qtvirtualkeyboard"
            ]
            ++ lib.optional (config.hostSpec.hdr) [
              "QT_SCREEN_SCALE_FACTORS=${config.hostSpec.scaling}"
              "QT_FONT_DPI=192"
            ]
          );
        in
        {
          GreeterEnvironment = lib.concatStringsSep "," greeterEnvVars;
          InputMethod = "qtvirtualkeyboard";
        };
    };
  };
}
