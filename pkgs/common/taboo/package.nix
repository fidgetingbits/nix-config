{ vimUtils, fetchFromGitHub }:
let
  pname = "taboo.vim";
in
vimUtils.buildVimPlugin {
  inherit pname;
  version = "2019-08-27";
  dontBuild = true;
  src = fetchFromGitHub {
    owner = "gcmt";
    repo = pname;
    rev = "caf948187694d3f1374913d36f947b3f9fa1c22f";
    sha256 = "sha256-KUkdaaC7vW9nL6hivkVcyaf053d+1AyLuyS/sWz78Ro=";
  };
  meta.homepage = "https://github.com/gcmt/${pname}";
}
