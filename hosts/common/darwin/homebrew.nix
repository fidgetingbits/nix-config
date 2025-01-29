{ ... }:
{
  # This is required to install yubico packages, but it doesn't actually work
  # because we need it to run first..., so for now I use the bootstrap script
  # system.activationScripts.extraActivation.text = ''
  #   softwareupdate --install-rosetta --agree-to-license
  # '';

  # Mostly from: https://github.com/malob/nixpkgs/blob/master/darwin/homebrew.nix
  homebrew.enable = true;
  homebrew.onActivation.autoUpdate = true;
  homebrew.onActivation.cleanup = "zap";
  homebrew.global.brewfile = true;

  homebrew.taps = [
    "homebrew/cask-fonts"
    "homebrew/cask-versions"
    "homebrew/services"
  ];

  # Prefer installing application from the Mac App Store
  #
  homebrew.masApps = {
    # "Yubico Authenticator" = 1497506650; # Waiting for apple I de reset
  };

  homebrew.casks = [
    "openvpn-connect"
    "firefox"
    "google-chrome"
    "yubico-yubikey-manager"
    "signal"
    "copyq"
    "utm" # QEMU front-end
    # "yubico-yubikey-personalization-gui" # No longer exists
  ];

  homebrew.brews = [
    "duti"
    "qemu"
  ];
}
