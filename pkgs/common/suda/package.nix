{ vimUtils, fetchFromGitHub }:
let
  pname = "suda.vim";
  owner = "lambdalisue";
in
vimUtils.buildVimPlugin {
  inherit pname;
  version = "2023-07-23";
  dontBuild = true;
  src = fetchFromGitHub {
    inherit owner;
    repo = pname;
    rev = "8b0fc3711760195aba104e2d190cff9af8267052";
    sha256 = "sha256-DFGPI85nLnHcyXKuWkUTL2sMQK2ylwFSSoXfb9WgzqQ=";
  };
  meta.homepage = "https://github.com/${owner}/${pname}";
}
