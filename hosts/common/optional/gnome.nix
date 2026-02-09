{ pkgs, lib, ... }:
{
  services.desktopManager.gnome.enable = true;
  services.gnome.gnome-keyring.enable = true;

  environment.gnome.excludePackages = lib.attrValues {
    inherit (pkgs)
      gnome-photos
      gnome-tour
      gnome-text-editor # important otherwise overrides mime-types
      gedit # text editor
      gnome-console # favor gnome-terminal
      cheese # webcam tool
      atomix # puzzle game
      epiphany # web browser
      geary # email reader
      gnome-characters
      iagno # go game
      hitori # sudoku game
      tali # poker game
      simple-scan
      totem
      # video player
      gnome-maps
      gnome-weather
      gnome-music
      yelp # Help view
      gnome-contacts
      gnome-initial-setup
      papers # pdf viewer
      ;

  };
  programs.dconf.enable = true;
  environment.systemPackages = lib.attrValues {
  };
  #services.touchegg.enable = true;

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  systemd.oomd.enable = false; # Try to prrevent Gnome BSOD
}
