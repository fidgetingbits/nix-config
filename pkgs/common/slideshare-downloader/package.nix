# https://github.com/yodiaditya/slideshare-downloader
{
  lib,
  fetchFromGitHub,
  python3Packages,
  makeWrapper,
}:
python3Packages.buildPythonApplication rec {
  name = "slideshare-downloader";
  version = "0-unstable-2024-10-12";
  format = "other";

  src = fetchFromGitHub {
    owner = "fidgetingbits";
    repo = "slideshare-downloader";
    rev = "fa5e355e7821681b09384eeec3da5da4e7059eca";
    hash = "sha256-y42AkA9Lpq1wkE9PAGjfqSEDtDcJdSSig3M9em5ATPE=";
  };
  buildInputs = [
    makeWrapper
  ];
  propagatedBuildInputs = with python3Packages; [
    img2pdf
    beautifulsoup4
    requests
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/
    cp -r slideshare2pdf.py $out/share/

    runHook postInstall
  '';

  fixupPhase = ''
    runHook preFixup

    echo $PYTHONPATH
    makeWrapper ${python3Packages.python}/bin/python "$out/bin/${name}" \
      --set PYTHONPATH "$PYTHONPATH" \
      --add-flags "$out/share/slideshare2pdf.py"

    runHook postFixup
  '';

  meta = {
    description = "Tool to download Slideshare slides without login and converted into pdf with high-resolution automatically.";
    homepage = "https://github.com/yodiaditya/slideshare-downloader";
    # license = lib.licenses.none;
    maintainers = with lib.maintainers; [ fidgetingbits ];
    mainProgram = name;
    platforms = lib.platforms.all;
  };
}
