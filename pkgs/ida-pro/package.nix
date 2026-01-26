# Adapted from https://github.com/misaka18931/misakaPkgs/blob/main/pkgs/ida-pro/package.nix
# with crack removed and some other minor changes
# FIXME: idapython is currently broken for some reason:
# ```
# WARNING: Python 3 is not configured (Python3TargetDLL value is not set).
# Please run idapyswitch to select a Python 3 install.
# failed to load Python runtime: skipping IDAPython plugin
# ```

{
  autoPatchelfHook,
  cairo,
  copyDesktopItems,
  copyPathToStore,
  dbus,
  fetchurl,
  fontconfig,
  freetype,
  glib,
  gtk3,
  lib,
  libdrm,
  libGL,
  libkrb5,
  libsecret,
  libsForQt5,
  libunwind,
  libxkbcommon,
  makeDesktopItem,
  makeWrapper,
  openssl,
  python3,
  stdenv,
  xorg,
  zlib,
  pythonEnv ? python3,
}:

#   srcs = lib.strings.fromJSON (lib.readFile ./srcs.json);
let
  dummyFile = builtins.toFile "dummy-ida.run" "dummy file for CI";
  idaFile = "${builtins.getEnv "REPO_PATH"}/pkgs/nixos/ida-pro/ida-pro_90_x64linux.run";
  isDummyBuild = builtins.getEnv "REPO_PATH" == "" || (!lib.pathExists idaFile);
in
stdenv.mkDerivation rec {
  pname = "ida-pro";
  version = "9.0.240925";

  # FIXME: This needs to switch to download from some private system since this is impure, and will break CI nix flake check
  # src = copyPathToStore "${builtins.getEnv "REPO_PATH"}/pkgs/nixos/ida-pro/ida-pro_90_x64linux.run";
  src = if isDummyBuild then dummyFile else copyPathToStore idaFile;

  # This file is purposefully not included in the repository.
  # src = fetchurl {
  #   inherit (srcs.${stdenv.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}"))
  #     urls
  #     hash
  #     ;
  # };
  # patcher = ./patch.py;

  icon = fetchurl {
    urls = [ "https://hex-rays.com/products/ida/news/8_1/images/icon_teams.png" ];
    sha256 = "sha256-Ufd7+Ea+80AW6b/KG4fPSOtZm3AEfbxdxNDWeVZ0LcM=";
  };

  desktopItem = makeDesktopItem {
    name = "ida-pro";
    # exec = ''env QT_QPA_PLATFORM="xcb;wayland" ida64'';
    exec = "ida";
    icon = icon;
    comment = meta.description;
    desktopName = "IDA Pro";
    genericName = "Interactive Disassembler";
    categories = [ "Development" ];
    startupWMClass = "IDA";
  };

  desktopItems = [ desktopItem ];

  nativeBuildInputs = [
    makeWrapper
    copyDesktopItems
    autoPatchelfHook
    libsForQt5.wrapQtAppsHook
    pythonEnv
  ];

  # We just get a runfile in $src, so no need to unpack it.
  dontUnpack = true;

  # Add everything to the RPATH, in case IDA decides to dlopen things.
  runtimeDependencies = [
    cairo
    dbus
    fontconfig
    freetype
    glib
    gtk3
    libdrm
    libGL
    libkrb5
    libsecret
    libsForQt5.qtbase
    libsForQt5.qtwayland
    libunwind
    libxkbcommon
    openssl
    pythonEnv
    stdenv.cc.cc
    xorg.libICE
    xorg.libSM
    xorg.libX11
    xorg.libXau
    xorg.libxcb
    xorg.libXext
    xorg.libXi
    xorg.libXrender
    xorg.xcbutilimage
    xorg.xcbutilkeysyms
    xorg.xcbutilrenderutil
    xorg.xcbutilwm
    zlib
  ];
  buildInputs = runtimeDependencies; # + copyPathTheStore src;

  dontWrapQtApps = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib $out/opt

    # IDA depends on quite some things extracted by the runfile, so first extract everything
    # into $out/opt, then remove the unnecessary files and directories.
    IDADIR=$out/opt

    # Invoke the installer with the dynamic loader directly, avoiding the need
    # to copy it to fix permissions and patch the executable.
    $(cat $NIX_CC/nix-support/dynamic-linker) $src \
      --mode unattended --prefix $IDADIR

    # crack patching
    # Copy the exported libraries to the output.
    # cp $IDADIR/libida64.so $out/lib
    # python $patcher $IDADIR/libida64.so $out/lib/libida64.so
    # RES_DIR=$PWD
    # cd $IDADIR
    # python $patcher
    # mv libida.so.patched libida.so
    # mv libida64.so.patched libida64.so
    # cd $RES_DIR
    # cp $IDADIR/libida64.so $out/lib

    mv $IDADIR/dbgsrv $out/share

    # Some libraries come with the installer.
    addAutoPatchelfSearchPath $IDADIR

    for bb in ida assistant; do
      wrapProgram $IDADIR/$bb \
        --prefix QT_PLUGIN_PATH : $IDADIR/plugins/platforms \
        --prefix NIX_PYTHONPREFIX : ${pythonEnv} \
        --prefix NIX_PYTHONEXECUTABLE : ${pythonEnv}/bin/${pythonEnv.executable} \
        --prefix NIX_PYTHONPATH : ${pythonEnv}/${pythonEnv.sitePackages} \
        --prefix 'PYTHONNOUSERSITE' : 'true'
      ln -s $IDADIR/$bb $out/bin/$bb
    done

    # runtimeDependencies don't get added to non-executables, and openssl is needed
    #  for cloud decompilation
    patchelf --add-needed libcrypto.so $IDADIR/libida.so

    # enable python env
    patchelf --add-needed libpython3.so $IDADIR/plugins/idapython3.so


    runHook postInstall
  '';

  meta = with lib; {
    description = "The world's smartest and most feature-full disassembler";
    homepage = "https://hex-rays.com/ida-pro/";
    changelog = "https://hex-rays.com/products/ida/news/";
    license = licenses.unfree;
    mainProgram = "ida";
    maintainers = [ "misaka18931" ];
    platforms = [ "x86_64-linux" ]; # Right now, the installation script only supports Linux.
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
