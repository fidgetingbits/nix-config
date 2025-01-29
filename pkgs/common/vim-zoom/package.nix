{ vimUtils, fetchFromGitHub }:
let
  pname = "vim-zoom";
in
vimUtils.buildVimPlugin {
  inherit pname;
  version = "2023-01-24";
  dontBuild = true;
  src = fetchFromGitHub {
    owner = "dhruvasagar";
    repo = pname;
    rev = "01c737005312c09e0449d6518decf8cedfee32c7";
    sha256 = "sha256-/ADzScsG0u6RJbEtfO23Gup2NYdhPkExqqOPVcQa7aQ=";
  };
  meta.homepage = "https://github.com/dhruvasagar/${pname}";
}
