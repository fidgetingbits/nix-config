{ config, pkgs, ... }:
{
  # Automatically try to unlock gnome-keyring on login
  security.pam.services.gdm = {
    u2fAuth = true;
    enableGnomeKeyring = true;
  };

  # FIXME: This doesn't actually work yet
  # check: https://github.com/jojowaldi/nix/blob/ad2589c1c037a3953dbf9fe154cdb164dc58752c/modules/home/security.nix#L6
  # https://unix.stackexchange.com/questions/551021/how-to-unlock-gnome-keyring-after-passwordless-login-with-solokey-yubiko
  # https://github.com/recolic/gnome-keyring-yubikey-unlock
  # https://discourse.nixos.org/t/automatically-unlocking-the-gnome-keyring-using-luks-key-with-greetd-and-hyprland/54260
  security.pam.services.gdm-autologin-keyring.text = ''
    auth      optional      ${pkgs.gdm}/lib/security/pam_gdm.so
    auth      optional      ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so
  '';

  services.xserver.displayManager.gdm.enable = true;
  services.xserver.displayManager.gdm.wayland = config.hostSpec.useWayland;

}
