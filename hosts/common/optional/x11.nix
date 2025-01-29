{ pkgs, config, ... }:
{
  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable automatic login for the user.
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = config.hostSpec.username;

  environment.systemPackages = [
    pkgs.xorg.xf86inputevdev # for gilrs used by talon. need evdev
  ];
}
