{
  pkgs,
  ...
}:

{
  home.packages = [
    #(pkgs.signal-desktop.override { commandLineArgs = "--password-store='gnome-libsecret'"; })
    pkgs.signal-desktop
  ];
}
