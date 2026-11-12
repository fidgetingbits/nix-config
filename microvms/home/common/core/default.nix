# base home-manager module for microvms
{
  pkgs,
  lib,
  user,
  vmSpecs,
  ...
}:
{
  imports = lib.flatten [
    (map lib.custom.relativeToRoot [
      "home/common/core/zellij"
    ])
  ];

  home = {
    username = user;
    homeDirectory = "/home/${user}";
    stateVersion = "26.05";

    packages = lib.attrValues {
      inherit (pkgs)
        delta
        difftastic
        direnv
        fd
        git
        htop
        just
        jq
        ripgrep
        tree
        curl
        python3
        openssh
        neovim # FIXME: (overlay our neovim package, etc?)
        strace
        wget
        zoxide
        ;
    };
  };

  xdg.enable = true;

  programs = {
    home-manager.enable = true;
    zsh = {
      enable = true;
      shellAliases = {
        "cds" = "cd ${vmSpecs.sharedDir}/shared/$(hostname)/";
      };

      oh-my-zsh = {
        enable = true;
        plugins = [
          "grc" # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/grc
          "eza" # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/eza/
          "cp" # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/cp
          "git" # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/git
          "zoxide" # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/zoxide
          "systemd" # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/systemd
          "colored-man-pages" # # https://github.com/ohmyzsh/ohmyzsh/blob/master/plugins/colored-man-pages/colored-man-pages.plugin.zsh

        ];
        extraConfig = ''
          # Disable built-in git aliases, as I prefer my own
          zstyle ':omz:plugins:git' aliases no
        '';
      };
    };
  };

}
