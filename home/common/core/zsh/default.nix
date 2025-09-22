{
  config,
  lib,
  pkgs,
  ...
}:
let
  homeDirectory = config.home.homeDirectory;
in
{
  home.packages = [
    pkgs.bitwarden-cli # for cmd line password generation
    pkgs.rmtrash # temporarily cache deleted files for recovery
    pkgs.fzf # fuzzy finder used by initExtra.zsh
    pkgs.comma # run ", command" to run a cmd in temp nix shell
  ];
  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    completionInit = ''
      autoload bashcompinit && bashcompinit
    '';
    syntaxHighlighting.enable = true;
    dotDir = ".config/zsh";
    autocd = true;
    history.size = 500000;
    history.share = false; # Rely on atuin for this

    # NOTE: zsh module will load *.plugin.zsh files by default if they are located in the src=<folder>, so
    # supply the full folder path to the plugin in src=. To find the correct path, atm you must check the
    # plugins derivation until PR XXXX (file issue) is fixed
    plugins = import ./plugins.nix {
      inherit pkgs lib;
    };

    initContent = lib.mkMerge [
      (lib.mkBefore ''
        zmodload zsh/zprof # profiling startup times

        # Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
        # Initialization code that may require console input (password prompts, [y/n]
        # confirmations, etc.) must go above this block; everything else may go below.
        if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi

        source "${pkgs.fzf-git-sh}/share/fzf-git-sh/fzf-git.sh"
        source ${pkgs.fzf}/share/fzf/key-bindings.zsh

        bindkey '^[k' kyd # Bind kyd alias to Alt+k

      '')
      (lib.mkAfter (lib.readFile ./zshrc))
    ];

    oh-my-zsh = {
      enable = true;
      plugins = [
        "gcloud" # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/gcloud
        "grc" # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/grc
        "eza" # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/eza/
        "cp" # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/cp
        "git" # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/git
        "zoxide" # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/zoxide
        # FIXME(zsh): Remap this to use something other than esc twice
        #"sudo" # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/sudo
        "systemd" # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/systemd
        "colored-man-pages" # # https://github.com/ohmyzsh/ohmyzsh/blob/master/plugins/colored-man-pages/colored-man-pages.plugin.zsh

      ];
      extraConfig = ''
        # Disable built-in git aliases, as I prefer my own
        zstyle ':omz:plugins:git' aliases no

        # Ignore blacklisted paths
        zstyle ':completion:*:*directories' ignored-patterns '${homeDirectory}/mount/*' '${homeDirectory}/mnt/*'
        zstyle ':completion:*:*files' ignored-patterns '${homeDirectory}/mount/*' '${homeDirectory}/mnt/*'

        # Load extract plugin files if they exist
        test -f ~/.nix-profile/etc/grc.zsh && source ~/.nix-profile/etc/grc.zsh

      '';
    };

    sessionVariables = {
      EDITOR = config.hostSpec.defaultEditor;
      BAT_THEME = "Dracula"; # Stylix bug, they use "dracula" instead of "Dracula"
      #
      # FZF key-binding.zsh tweaks
      #
      FZF_CTRL_R_COMMAND = ""; # Disable, as we favor atuin
      #FZF_CTRL_T_COMMAND = "fd --type f --hidden --follow --exclude .git";
      FZF_CTRL_T_COMMAND = "fd --type f --exclude .git";
      FZF_CTRL_T_OPTS = "--preview '(highlight -O ansi -l {} 2> /dev/null || cat {} || tree -C {}) 2> /dev/null | head -200'";
    }
    // lib.optionalAttrs (config.hostSpec.isProduction && (!config.hostSpec.isServer)) {
      OPENAI_API_KEY = "$(cat ${homeDirectory}/.config/openai/token)";
    };

    shellAliases = import ./aliases.nix;
  };
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
  };
}
