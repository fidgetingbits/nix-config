# Fork of gef.py that typically has way more features
# https://github.com/bata24/gef/blob/dev/gef.py
# This is mostly similar to the gef package
{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  gdb,
  python3,
  bintools-unwrapped,
  file,
  ps,
  git,
  coreutils,
}:

let
  pythonPath = python3.pkgs.makePythonPath (
    lib.attrValues {
      inherit (python3.pkgs)
        keystone-engine
        unicorn
        capstone
        ropper
        ;
    }
  );
in
stdenv.mkDerivation rec {
  pname = "bata24-gef";
  version = "81b3fb9dd8439348ddf5495bfc6469ff4f3edeb2";

  src = fetchFromGitHub {
    owner = "bata24";
    repo = "gef";
    rev = version;
    sha256 = "sha256-uSUr2NFvj7QIlvG3RWYm7A9Xx7a4JYkbAQld7c7+C7g=";
  };

  dontBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/share/gef
    cp gef.py $out/share/gef
    makeWrapper ${gdb}/bin/gdb $out/bin/bata24-gef \
      --add-flags "-q -x $out/share/gef/gef.py" \
      --set NIX_PYTHONPATH ${pythonPath} \
      --prefix PATH : ${
        lib.makeBinPath [
          python3
          bintools-unwrapped # for readelf
          file
          ps
        ]
      }
  '';

  nativeCheckInputs = [
    gdb
    file
    ps
    git
    python3
    python3.pkgs.pytest
    python3.pkgs.pytest-xdist
    python3.pkgs.keystone-engine
    python3.pkgs.unicorn
    python3.pkgs.capstone
    python3.pkgs.ropper
  ];
  checkPhase = ''
    # Skip some tests that require network access.
    sed -i '/def test_cmd_shellcode_get(self):/i \ \ \ \ @unittest.skip(reason="not available in sandbox")' tests/runtests.py
    sed -i '/def test_cmd_shellcode_search(self):/i \ \ \ \ @unittest.skip(reason="not available in sandbox")' tests/runtests.py

    # Patch the path to /bin/ls.
    sed -i 's+/bin/ls+${coreutils}/bin/ls+g' tests/runtests.py

    # Run the tests.
    make test
  '';

  meta = {
    description = "A modern experience for GDB with advanced debugging features for exploit developers & reverse engineers";
    mainProgram = "bata24-gef";
    homepage = "https://github.com/bata24/gef";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
    maintainers = [ ];
  };
}
