{
  stdenv,
  pkgs,
  lib,
  ...
}:
let
  pname = "easylkb";
  makeWrapper = pkgs.writeTextFile {
    name = "make-wrapper";
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      export KCFLAGS="-fno-pie -fno-stack-protector"
      export KAFLAGS="-fno-pie"
      exec make "$@"
    '';
  };

  # This is only for use by the make scripts, which has unpatchable FHS path expectations
  fhsEnv = pkgs.buildFHSUserEnv {
    name = "kernel-build-env";
    targetPkgs =
      pkgs:
      lib.flatten [
        (builtins.attrValues {
          inherit (pkgs)
            python3
            pkg-config
            gnumake
            ncurses

            binutils
            linuxHeaders
            libelf
            flex
            bison
            gdb
            strace
            gcc

            ;

          inherit (pkgs.openssl) dev;
          inherit (pkgs.qt5) qtbase;
          inherit (pkgs.linux) nativeBuildInputs;
        })
      ];
    runScript = "${makeWrapper}";
  };
  easylkb = stdenv.mkDerivation {
    pname = pname;
    version = "0-unstable-2024-04-03";
    src = pkgs.fetchFromGitHub {
      owner = "fidgetingbits";
      repo = "easylkb";
      rev = "d5159550ef15d25e7a502aefb50d9cf2b6f25a01";
      sha256 = "sha256-HiXMz7PU5glMkSNt/POY/2mpMiQv2Nnm68V/U8cmbB4=";
    };
    #src = builtins.fetchGit {
    #url = "file:///home/aa/dev/easylkb";  # Path to your local repo

    patchPhase = ''
      sed -i 's,/bin/bash,${pkgs.bash}/bin/bash,g' ./easylkb.py
      # The calls to make must be within the FHS build environment instead
      sed -i 's,"make","${fhsEnv}/bin/kernel-build-env",g' ./easylkb.py
      # 2GB is not enough in practice
      sed -i 's/SEEK=2047/SEEK=4095/g' ./kernel/create-image.sh
    '';
    installPhase = ''
      pwd
      mkdir -p $out/{bin,share}/
      # Copy the main script and resource directories
      cp ./${pname}.py $out/share/
      cp -r config $out/share/
      # Nix installs this as r-x, but a script will try to overwrite a copy of it, so make it writable
      chmod +w kernel/create-image.sh
      cp -r kernel $out/share/
    '';
  };
in
pkgs.writeShellApplication {
  name = "easylkb";
  runtimeInputs = lib.flatten [
    (builtins.attrValues {
      inherit (pkgs)
        e2fsprogs # mkfs.ext4
        curl
        qemu
        ;
    })
    pkgs.unstable.debootstrap # unstable important for zstd support
    pkgs.linux.nativeBuildInputs
  ];
  # propagatedBuildInputs =  builtins.attrValues {inherit (pkgs) gdb;};
  text = ''
    #!/usr/bin/env bash

    XDG_CONFIG_HOME=''${XDG_CONFIG_HOME:-$HOME/.config}
    mkdir -p "$XDG_CONFIG_HOME"/${pname}/share/{kernel,config} || true
    ln -sf ${easylkb}/share/config/example.KConfig "$XDG_CONFIG_HOME/${pname}/share/config/example.KConfig"
    ln -sf ${easylkb}/share/kernel/create-image.sh "$XDG_CONFIG_HOME/${pname}/share/kernel/create-image.sh"
    cd "$XDG_CONFIG_HOME/${pname}/share/"
    exec ${pkgs.python3}/bin/python ${easylkb}/share/${pname}.py "$@"
    # exec ${fhsEnv}/bin/kernel-build-env "$@"
  '';
  meta = {
    homepage = "https://github.com/deepseagirl/easylkb";
    license = lib.licenses.mit;
    longDescription = ''
      easylkb is a simple script designed to make Linux Kernel Debugging easier and more accessible.
    '';

    maintainers = [ lib.maintainers.fidgetingbits ];
  };
}
