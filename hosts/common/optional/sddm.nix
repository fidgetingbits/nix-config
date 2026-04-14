{
  inputs,
  config,
  lib,
  ...
}:
{
  imports = [ inputs.silentSDDM.nixosModules.default ];

  programs.silentSDDM = {
    enable = true;
    theme = "rei";
    settings.General =
      let
        greeterEnvVars = lib.flatten (
          lib.optional config.hostSpec.hdr [
            "QT_SCREEN_SCALE_FACTORS=${config.hostSpec.scaling}"
            "QT_FONT_DPI=${toString config.services.xserver.dpi}"
          ]
        );
      in
      {
        GreeterEnvironment = lib.concatStringsSep "," greeterEnvVars;
      };
  };
  security.pam.services.sddm.enableGnomeKeyring = true;
}
