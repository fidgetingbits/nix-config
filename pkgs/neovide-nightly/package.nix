{
  lib,
  rustPlatform,
  clangStdenv,
  fetchFromGitHub,
  linkFarm,
  fetchgit,
  runCommand,
  gn,
  neovim,
  ninja,
  makeWrapper,
  pkg-config,
  python3,
  removeReferencesTo,
  cctools,
  SDL2,
  fontconfig,
  libxrandr,
  libxi,
  libxext,
  libxcursor,
  libx11,
  stdenv,
  libglvnd,
  libxkbcommon,
  enableWayland ? stdenv.hostPlatform.isLinux,
  wayland,
}:

rustPlatform.buildRustPackage.override { stdenv = clangStdenv; } (finalAttrs: rec {
  pname = "neovide";
  # version = "main";
  # Some nightly build to avoid regular rebuilds since they keep changing skia
  # I just want something that runs neovim 0.13 while they are still on 0.16.2
  version = "105fd640f83616501d7c6bfedb0b4c15ab9515e1";

  src = fetchFromGitHub {
    owner = "neovide";
    repo = "neovide";
    # tag = finalAttrs.version;
    rev = version;
    hash = "sha256-AZHPq5x3CGCbGtuSQJvK0YUC4EEiVZQ5znJzyFcqgrE=";
  };

  cargoHash = "sha256-f0SvBpNdsxOxukedxCBvUG4rgwC/Z6nhuiOhCVAQ40I=";

  env = {
    SKIA_SOURCE_DIR =
      let
        repo = fetchFromGitHub {
          owner = "rust-skia";
          repo = "skia";
          # see rust-skia:skia-bindings/Cargo.toml#package.metadata skia
          # IMPORTANT: If you change this, don't forget to run ./gen-skia-externals.py <tag>
          tag = "m153-0.101.2";
          # hash = lib.fakeHash;
          hash = "sha256-xKCkvQoTAMlLvKdVzzSxTST6kER4kRUIDjvTRZ9z72o=";
        };
        # The externals for skia are taken from skia/DEPS
        externals = linkFarm "skia-externals" (
          lib.mapAttrsToList (name: value: {
            inherit name;
            path = fetchgit value;
          }) (lib.importJSON ./skia-externals.json)
        );
      in
      runCommand "source" { } ''
        cp -R ${repo} $out
        chmod -R +w $out
        ln -s ${externals} $out/third_party/externals
      '';

    SKIA_GN_COMMAND = "${gn}/bin/gn";
    SKIA_NINJA_COMMAND = "${ninja}/bin/ninja";
  };

  nativeBuildInputs = [
    makeWrapper
    pkg-config
    python3 # skia
    removeReferencesTo
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    cctools.libtool
  ];

  nativeCheckInputs = [ neovim ];

  buildInputs = [
    SDL2
    fontconfig
    rustPlatform.bindgenHook
  ];

  postFixup =
    let
      libPath = lib.makeLibraryPath (
        [
          libglvnd
          libxkbcommon
          libx11
          libxcursor
          libxext
          libxrandr
          libxi
        ]
        ++ lib.optionals enableWayland [ wayland ]
      );
    in
    ''
      # library skia embeds the path to its sources
      remove-references-to -t "$SKIA_SOURCE_DIR" \
        $out/bin/neovide
    ''
    + lib.optionalString stdenv.hostPlatform.isLinux ''
      wrapProgram $out/bin/neovide \
        --prefix LD_LIBRARY_PATH : ${libPath}
    '';

  postInstall =
    lib.optionalString stdenv.hostPlatform.isDarwin ''
      mkdir -p $out/Applications
      cp -r extra/osx/Neovide.app $out/Applications
      ln -s $out/bin $out/Applications/Neovide.app/Contents/MacOS
    ''
    + lib.optionalString stdenv.hostPlatform.isLinux ''
      for n in 16x16 32x32 48x48 256x256; do
        install -m444 -D "assets/neovide-$n.png" \
          "$out/share/icons/hicolor/$n/apps/neovide.png"
      done
      install -m444 -Dt $out/share/icons/hicolor/scalable/apps assets/neovide.svg
      install -m444 -Dt $out/share/applications assets/neovide.desktop
    '';

  disallowedReferences = [ finalAttrs.env.SKIA_SOURCE_DIR ];

  meta = {
    description = "Simple, no-nonsense, cross-platform graphical user interface for Neovim";
    mainProgram = "neovide";
    homepage = "https://neovide.dev/";
    changelog = "https://github.com/neovide/neovide/releases/tag/${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [
      ck3d
      caverav
    ];
    platforms = lib.platforms.unix;
  };
})
