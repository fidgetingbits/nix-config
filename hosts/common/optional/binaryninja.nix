# An example of some plugin handling here:
# https://github.com/bsendpacket/nixcfg/blob/a6bdd2b934de29fb4d92f454ff564c4b835961e0/binary-ninja/config.nix#L2
{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
let
  sopsFolder = (builtins.toString inputs.nix-secrets) + "/sops";
  homeDirectory = "/home/${config.hostSpec.username}";
  icon = pkgs.fetchurl {
    urls = [ "https://rust.binary.ninja/logo.png" ];
    sha256 = "sha256-TzGAAefTknnOBj70IHe64D6VwRKqIDpL4+o9kTw0Mn4=";
  };
  desktopItem = pkgs.makeDesktopItem {
    desktopName = "Binary Ninja";
    name = "binaryninja";
    # We use substituteInPlace after we run `install`
    exec = "@out@/bin/binaryninja %u";
    mimeTypes = [
      "text/x-scheme-handler/binaryninja"
      "text/x-binaryninja"
    ];
    inherit icon;
    terminal = false;
    type = "Application";
    categories = [
      "Utility"
    ];
  };
  binaryninja = pkgs.buildFHSEnv {
    name = "binaryninja";
    targetPkgs =
      pkgs:
      (
        builtins.attrValues {
          inherit (pkgs)
            dbus
            fontconfig
            freetype
            libGL
            libxml2
            libxkbcommon
            python311
            wayland
            zlib
            gdb
            ;
          inherit (pkgs.xorg)
            libX11
            libxcb
            xcbutilimage
            xcbutilkeysyms
            xcbutilrenderutil
            xcbutilwm
            ;
        }
        ++ [ (pkgs.python311.withPackages (ps: builtins.attrValues { inherit (ps) pypresence; })) ]
      );
    runScript = pkgs.writeScript "binaryninja.sh" ''
      set -e
      exec "/opt/binaryninja/binaryninja"
    '';
    extraInstallCommands = ''
      install -Dm644 ${desktopItem}/share/applications/binaryninja.desktop $out/share/applications/binaryninja.desktop
      substituteInPlace $out/share/applications/binaryninja.desktop \
        --replace "@out@" ${placeholder "out"}
    '';
    meta = {
      description = "BinaryNinja";
      platforms = [ "x86_64-linux" ];
    };
  };

in
{
  environment =
    {
      systemPackages = [ binaryninja ];
    }
    // lib.optionalAttrs config.system.impermanence.enable {
      persistence = {
        "${config.hostSpec.persistFolder}".directories = [ "/opt/binaryninja" ];
      };
    };
  sops.secrets = {
    "licenses/binaryninja" = {
      sopsFile = "${sopsFolder}/development.yaml";
      owner = config.users.users.${config.hostSpec.username}.name;
      inherit (config.users.users.${config.hostSpec.username}) group;
      path = "${homeDirectory}/.binaryninja/license.dat";
    };
  };
}
