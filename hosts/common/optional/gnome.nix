{ pkgs, ... }:
{
  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.displayManager.gdm.wayland = false;
  services.xserver.desktopManager.gnome.enable = true;
  services.displayManager.defaultSession = "gnome";
  services.gnome.gnome-keyring.enable = true;
  # Automatically try to unlock gnome-keyring on login
  security.pam.services.gdm.enableGnomeKeyring = true;

  # https://unix.stackexchange.com/questions/551021/how-to-unlock-gnome-keyring-after-passwordless-login-with-solokey-yubiko
  # https://github.com/recolic/gnome-keyring-yubikey-unlock
  # https://discourse.nixos.org/t/automatically-unlocking-the-gnome-keyring-using-luks-key-with-greetd-and-hyprland/54260
  security.pam.services.gdm-autologin-keyring.text = ''
    auth      optional      ${pkgs.gdm}/lib/security/pam_gdm.so
    auth      optional      ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so
  '';

  environment.gnome.excludePackages = builtins.attrValues {
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
      ;

  };
  programs.dconf.enable = true;
  environment.systemPackages = builtins.attrValues {
  };
  #services.touchegg.enable = true;

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # Fix an issue related to gnome 47 overlays
  #services.gnome.gnome-online-miners.enable = lib.mkForce false;
}
