# All users get git no matter what, but most additional settings are added by
# ./../optional/development/git.nix, introdus
{
  pkgs,
  lib,
  ...
}:
{
  home.packages = [
    pkgs.delta # git diff tool
  ];

  introdus.color-conventional-commits = {
    enable = true;
  };

  programs.git = {
    package = pkgs.gitFull;
    enable = true;

    settings = {
      core.pager = "delta";
      delta = {
        enable = true;
        features = [
          "side-by-side"
          "line-numbers"
          "hyperlinks"
          "line-numbers"
          "commit-decoration"
        ];
      };
      alias.edit = "!$EDITOR $(git status --porcelain | awk '{print $2}')";
    };
  };

  # I want to default to glo for my muscle memory gl now, so adding a gll (long)
  programs.zsh.shellAliases = {
    gll = "git log";
    gl = lib.mkForce "glo";
  };

}
