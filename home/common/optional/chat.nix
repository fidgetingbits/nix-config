{
  pkgs,
  ...
}:

{
  home.packages = [
    (pkgs.unstable.signal-desktop.override { commandLineArgs = "--password-store='gnome-libsecret'"; })
  ];
}
