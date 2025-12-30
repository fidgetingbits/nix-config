# All users get git no matter, what but most additional settings are added by
# eg: development/git.nix, introdus
{
  pkgs,
  osConfig,
  ...
}:
{
  home.packages = [
    pkgs.delta # git diff tool
  ];

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

  home.sessionVariables.GIT_EDITOR = osConfig.hostSpec.defaultEditor;
}
