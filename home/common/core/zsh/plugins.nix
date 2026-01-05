{ pkgs }:
[
  {
    name = "zhooks";
    src = "${pkgs.zsh-zhooks}/share/zsh/zhooks";
  }
  {
    name = "you-should-use";
    src = "${pkgs.zsh-you-should-use}/share/zsh/plugins/you-should-use";
  }
  {
    name = "zsh-vi-mode";
    src = "${pkgs.zsh-vi-mode}/share/zsh-vi-mode";
  }
  # Allow zsh to be used in nix-shell
  {
    name = "zsh-nix-shell";
    file = "nix-shell.plugin.zsh";
    src = pkgs.fetchFromGitHub {
      owner = "chisui";
      repo = "zsh-nix-shell";
      rev = "v0.8.0";
      sha256 = "1lzrn0n4fxfcgg65v0qhnj7wnybybqzs4adz7xsrkgmcsr0ii8b7";
    };
  }
  {
    name = "zsh-term-title";
    src = "${pkgs.introdus.zsh-term-title}/share/zsh/zsh-term-title";
  }
  {
    name = "cd-gitroot";
    src = "${pkgs.introdus.cd-gitroot}/share/zsh/cd-gitroot";
  }
  {
    name = "zsh-deep-autocd";
    src = "${pkgs.introdus.zsh-deep-autocd}/share/zsh/zsh-deep-autocd";
  }
  {
    name = "zsh-autols";
    src = "${pkgs.introdus.zsh-autols}/share/zsh/zsh-autols";
  }
  # {
  #   name = "zsh-talon-folder-completion";
  #   src = "${pkgs.introdus.zsh-talon-folder-completion}/share/zsh/zsh-talon-folder-completion";
  # }
  {
    name = "zsh-color-ssh-nvim-term";
    src = "${pkgs.introdus.zsh-color-ssh-nvim-term}/share/zsh/zsh-color-ssh-nvim-term";
  }
  {
    name = "zsh-edit";
    src = "${pkgs.zsh-edit}/share/zsh/zsh-edit";
  }
]
