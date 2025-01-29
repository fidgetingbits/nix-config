{ vimUtils, fetchFromGitHub }:
let
  pname = "indent-blankline.nvim";
in
vimUtils.buildVimPlugin {
  inherit pname;
  version = "2024-01-12";
  dontBuild = true;
  src = fetchFromGitHub {
    owner = "lukas-reineke";
    repo = pname;
    rev = "12e92044d313c54c438bd786d11684c88f6f78cd";
    sha256 = "sha256-T0tbTyD9+J7OWcvfrPolrXbjGiXzEXhTtgC9Xj3ANFc=";
  };
  meta.homepage = "https://github.com/lukas-reineke/${pname}";
}
