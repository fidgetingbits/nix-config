{ pkgs, ... }:
{
  programs.bat = {
    # https://github.com/sharkdp/bat
    # https://github.com/eth-p/bat-extras
    enable = true;
    package = pkgs.bat;
    config = {
      # Show Git modifications and file header (but no grid)
      style = "changes,header";
      # bat --list-themes
    };
    extraPackages = builtins.attrValues {
      inherit (pkgs.bat-extras)
        batgrep # search through and highlight files using ripgrep
        batdiff # Diff a file against the current git index, or display the diff between to files
        batman # read manpages using bat as the formatter
        ;
    };
  };
}
