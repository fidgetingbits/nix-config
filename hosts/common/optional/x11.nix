{ pkgs, config, ... }:
{
  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;

    dpi = if config.hostSpec.hdr then 192 else 96;
    upscaleDefaultCursor = config.hostSpec.hdr;

    # Configure keymap in X11
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  environment.systemPackages = [
    pkgs.xorg.xf86inputevdev # for gilrs used by talon. need evdev
  ];
}
