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
  programs.zsh = {
    shellAliases = {
      gll = "git log";
      gl = lib.mkForce "glo";
      # Copy the last commit id from a branch
      glc = "git-last-commit";
      glcf = "git-fuzzy-find-commit";
    };
    initContent =
      lib.mkAfter # bash
        ''
          # Print the last commit of the current or specified branch and it to
          # the clipboard
          git-last-commit() {
            if ! git rev-parse --is-inside-work-tree >/dev/null; then
              exit 1
            fi
            git log --oneline "$@" | head -1 | awk "{print \$1}" | wl-copy
            echo "$(wl-paste)"
          }

          # Fuzzy find the specified commit of the current or specified branch.
          # Print it and copy it to the clipboard
          # FIXME: Add a -f argument so you can fzf select the worktree, then fzf select multiple commits
          # this way we can map it to something like c-g c-c and select multiple commits to cherry pick, etc
          git-fuzzy-find-commit() {
            if ! git rev-parse --is-inside-work-tree >/dev/null; then
              exit 1
            fi
            glo "$@" | \
              fzf --ansi --preview "git show --color=always {1}" | \
              sed 's/\x1b\[[0-9;]*m//g' | \
              awk "{print \$1}" | \
              wl-copy
              echo "$(wl-paste)"
          }
        '';
  };

}
