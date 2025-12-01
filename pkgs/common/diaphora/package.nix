{
  lib,
  fetchFromGitHub,
  python3Packages,
  makeWrapper,
}:
let

  cdifflib = python3Packages.buildPythonPackage {
    pname = "cdifflib";
    version = "unstable-2022-08-19";
    src = fetchFromGitHub {
      owner = "mduggan";
      repo = "cdifflib";
      rev = "f750924a69b0f6b58b5d9094b68103d08262f663";
      hash = "sha256-goo0JAOu+7endLUkvkNLEKDief0IQISoEGq4E3UQQCE=";
    };
    doCheck = true;
    pyproject = true;
    build-system = [ python3Packages.setuptools ];

    meta = {
      description = "Python difflib sequence matcher reimplemented in C.";
      homepage = "https://github.com/mduggan/cdifflib";
      license = lib.licenses.bsd3;
      maintainers = with lib.maintainers; [ fidgetingbits ];
    };
  };

  pname = "diaphora";
in
python3Packages.buildPythonApplication rec {
  name = pname;
  version = "3.2.1";
  format = "other";

  src = fetchFromGitHub {
    owner = "joxeankoret";
    repo = "diaphora";
    rev = version;
    hash = "sha256-9sNGixIkmem/8TZtsC7fsNVV9HSbb5CRfNEP23oFqWc=";
  };
  buildInputs = [
    makeWrapper
  ];
  propagatedBuildInputs = with python3Packages; [
    numpy
    scikit-learn
    cdifflib
  ];

  #doCheck = true;
  #dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/
    cp -r . $out/share/

    runHook postInstall
  '';

  fixupPhase = ''
    runHook preFixup

    makeWrapper ${python3Packages.python}/bin/python "$out/bin/diaphora" \
      --set PYTHONPATH "$PYTHONPATH" \
      --add-flags "$out/share/diaphora.py"

    runHook postFixup
  '';

  meta = {
    description = "An advanced IDA database diffing tool";
    homepage = "https://github.com/joxeankoret/diaphora";
    changelog = "https://github.com/joxeankoret/diaphora/releases/tag/${version}";
    license = lib.licenses.agpl3Only;
    maintainers = with lib.maintainers; [ fidgetingbits ];
    mainProgram = "diaphora";
  };
}
