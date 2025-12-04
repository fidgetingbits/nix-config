{ pkgs, lib }:
[

  # FIXME(zsh): double check why I had added this in addition to my own theme above
  #  {
  #    name = "zsh-powerlevel10k";
  #    src = "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k";
  #    file = "powerlevel10k.zsh-theme";
  #  }
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
]
# Some hosts don't use overlays, so don't add custom packages unless they are there
++ lib.optionals (pkgs ? "zsh-term-title") [
  {
    name = "zsh-term-title";
    src = "${pkgs.zsh-term-title}/share/zsh/zsh-term-title";
  }
  {
    name = "cd-gitroot";
    src = "${pkgs.cd-gitroot}/share/zsh/cd-gitroot";
  }
  {
    name = "zsh-deep-autocd";
    src = "${pkgs.zsh-deep-autocd}/share/zsh/zsh-deep-autocd";
  }
  {
    name = "zsh-autols";
    src = "${pkgs.zsh-autols}/share/zsh/zsh-autols";
  }
  # {
  #   name = "zsh-talon-folder-completion";
  #   src = "${pkgs.zsh-talon-folder-completion}/share/zsh/zsh-talon-folder-completion";
  # }
  {
    name = "zsh-color-ssh-nvim-term";
    src = "${pkgs.zsh-color-ssh-nvim-term}/share/zsh/zsh-color-ssh-nvim-term";
  }
  {
    name = "zsh-edit";
    src = "${pkgs.zsh-edit}/share/zsh/zsh-edit";
  }
]
