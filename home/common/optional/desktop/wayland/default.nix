{ pkgs, lib, ... }:
{
  home.packages = [
    pkgs.wl-clipboard
    pkgs.unstable.grimblast
    (pkgs.writeShellScriptBin "flameshot-gui" ''
      export XDG_SESSION_TYPE=x11
      # export XDG_SESSION_TYPE=wayland
      # export QT_QPA_PLATFORM=wayland
      # export QT_AUTO_SCREEN_SCALE_FACTOR=0.5
      ${lib.getExe' pkgs.flameshot "flameshot"} gui
    '')
  ];

  # services.flameshot = {
  #   enable = true;
  #   package = pkgs.unstable.flameshot;
  #   settings = {
  #     General = {
  #       useGrimAdapter = true;
  #       disabledTrayIcon = false;
  #       showStartupLaunchMessage = true;
  #       showAbortNotification = true;
  #       historyConfirmationToDelete = false;
  #       showHelp = false;
  #       showMagnifier = true;
  #       showSidePanelButton = false;
  #       #        uiColor = "#0f111b";
  #       #        drawColor = "#D81E5B";
  #       drawThickness = 4;
  #
  #       # Save/Export.
  #       copyPathAfterSave = true;
  #     };
  #   };
  # };

}
