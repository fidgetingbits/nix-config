{
  pkgs,
  ...
}:
# FIXME(signal):
#  - This should get set only if we are using catppuccin on the host
#  - Dark theme isn't set on new install, so figure out how to specify that for hyprland, etc
let
  flavor = "mocha";
  catpuccin-theme = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/CalfMoon/signal-desktop/8696026510c04cb00d7d2222aef01f8940017172/themes/catppuccin-${flavor}.css";
    sha256 = "sha256-G+SXzbqgdd4DMoy6L+RW5xdoMMj3oCfd6hyalVnPkR4=";
  };
in
{
  home.packages = [
    # FIXME: This should get PRed into catppuccin nix repo or something
    (pkgs.unstable.signal-desktop.overrideAttrs (
      final: prev: {
        nativeBuildInputs = prev.nativeBuildInputs or [ ] ++ [ pkgs.asar ];
        postInstall = ''
          tmpdir=$(mktemp -d)

          cp $out/share/signal-desktop/app.asar $tmpdir/app.asar
          cp -r $out/share/signal-desktop/app.asar.unpacked $tmpdir/app.asar.unpacked
          chmod -R +w $tmpdir/app.asar.unpacked
          cd $tmpdir

          ${pkgs.asar}/bin/asar extract app.asar app
          cp ${catpuccin-theme} app/stylesheets/catppuccin-${flavor}.css
          sed -i '1i @import "catppuccin-${flavor}.css";' app/stylesheets/manifest.css

          ${pkgs.asar}/bin/asar pack --unpack '*.node' app app.asar

          cp app.asar $out/share/signal-desktop/app.asar
        '';
      }
    ))
  ];
}
