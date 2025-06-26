{
  config,
  lib,
  pkgs,
  ...
}:
let
  devFolder = "~/dev";
  devTalon = "${devFolder}/talon";
  devNix = "${devFolder}/nix";
  homeDirectory = config.home.homeDirectory;
in
{
  home.packages = [
    pkgs.bitwarden-cli # for cmd line password generation
    pkgs.rmtrash # temporarily cache deleted files for recovery
    pkgs.fzf # fuzzy finder used by initExtra.zsh
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
    # Rely on atuin for this
    history.share = false;

    # NOTE: zsh module will load *.plugin.zsh files by default if they are located in the src=<folder>, so
    # supply the full folder path to the plugin in src=. To find the correct path, atm you must check the
    # plugins derivation until PR XXXX (file issue) is fixed
    plugins =
      [
        {
          name = "powerlevel10k-config";
          src = ./p10k;
          file = "p10k.zsh.theme"; # NOTE: Don't use .zsh because of shfmt barfs on it, and can't ignore files
        }
        {
          name = "zsh-powerlevel10k";
          src = "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k";
          file = "powerlevel10k.zsh-theme";
        }
        {
          name = "zhooks";
          src = "${pkgs.zsh-zhooks}/share/zsh/zhooks";
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
      ];

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
      '')
      (lib.mkAfter (lib.readFile ./zshrc))
    ];

    # + ''export OPENAI_API_KEY="$(cat ${homeDirectory}/.config/openai/token)"'';

    oh-my-zsh = {
      enable = true;
      plugins = [
        "gcloud" # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/gcloud
        "grc" # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/grc
        "eza" # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/eza/
        "cp" # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/cp
        "git" # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/git
        "zoxide" # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/zoxide
        "sudo" # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/sudo
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

    sessionVariables =
      {
        EDITOR = if config.hostSpec.isServer then "nvim" else "code -w";
      }
      // lib.optionalAttrs (config.hostSpec.isProduction && (!config.hostSpec.isServer)) {
        OPENAI_API_KEY = "$(cat ${homeDirectory}/.config/openai/token)";

      };

    shellAliases = {
      whichreal = ''function _whichreal(){ (alias "$1" >/dev/null 2>&1 && (alias "$1" | sed "s/.*=.\(.*\).../\1/" | xargs which)) || which "$1"; }; _whichreal'';
      edit = "code -w";
      cat = "bat --paging=never";
      ldt = "eza -TD"; # list directory tree
      tree = "eza -T";
      gdb = "gdb -q";
      rg = "rg -M300";
      du = "dust";
      df = "duf";
      calc = "eva";
      hd = "hexyl --border none";
      hexdump = "hexyl --border none";
      # Path to real rm and rmdir in coreutils. This is so we can not use rmtrash for big files
      rrm = "/run/current-system/sw/bin/rm";
      rrmdir = "/run/current-system/sw/bin/rmdir";
      rm = "rmtrash";
      rmdir = "rmdirtrash";
      journactl = "journalctl --no-pager";
      unzip = "7z x";
      genpasswd = "bw generate --words 5 --includeNumber --ambiguous --separator '-' -p -c";

      # file searching
      fdi = "fd -I"; # fd with --no-ignore
      biggest = "find . -printf '%s %p\n'|sort -nr|head";

      # git
      gcm = "git commit -m";
      gcmcf = "git commit -m 'chore: update flake.lock'";
      gca = "git commit --amend";
      gcan = "git commit --amend --no-edit";

      # We use source because we want it to use other aliases, which allow yubikey signing over ssh
      gsr = "git_smart_rebase";
      grst = "git reset --soft ";

      gr = "git restore";
      gra = "git restore :/";
      grs = "git restore --staged";
      grsa = "git restore --staged :/";

      ga = "git add";
      gau = "git add --update";
      # Only add updates to files that are already staged
      gas = "git add --update $(git diff --name-only --cached)";
      gs = "git status --untracked-files=no";
      gsa = "git status";
      gst = "git stash";
      gstp = "git stash pop";
      gsw = "git switch";
      gswc = "git switch -c";
      gco = "git checkout";
      gf = "git fetch";
      gfa = "git fetch --all";
      gfu = "git fetch upstream";
      gfm = "git fetch origin master";
      gds = "git diff --staged";
      gd = "git diff";
      gp = "git push";
      gpf = "git push --force-with-lease";
      gl = "git log";
      gc = "git clone";

      # lsusb
      lsusb = "cyme --tree";

      # nix
      nr = "nix run .";
      nri = "nix run . --impure";
      nfu = "nix flake update";
      nfui = "nix flake lock --update-input";
      nfm = "nix flake metadata";
      nbp = "nix-build -E 'with import <nixpkgs> {}; pkgs.callPackage ./package.nix {}'"; # nbp: nix build package
      nrp = "nix run -E 'with import <nixpkgs> {}; pkgs.callPackage ./package.nix {}'"; # nrp: nix run package
      nswp = "nix shell nixpkgs#"; # nsw: nix shell with package
      nlg = "sudo nix profile history --profile /nix/var/nix/profiles/system";
      ncs = "REPO_PATH=$PWD nh os switch --no-nom . -- --impure"; # ncs = nix config switch
      nrepl = "nix repl --expr 'import <nixpkgs>{}'";

      # finding
      t = "tree";

      # processes
      p = "ps -ef";
      pg = "ps -ef | rg -i";
      k = "kill";
      k9 = "kill -9";
      kf = "ps -e | fzf | awk '{print $1}' | xargs kill";

      # folders
      # Directory convenience
      cdr = "cd-gitroot";
      cdpr = "..; cd-gitroot";
      zf = "cdf"; # Fuzzy jump to folder of file under tree
      zd = "cdd"; # Fuzzy jump to directory under tree

      ## talon
      ctc = "cd ${devTalon}/fidgetingbits-talon";
      ctp = "cd ${devTalon}/private";
      cnt = "cd ${devTalon}/neovim-talon";
      ctn = "cd ${devTalon}/talon.nvim";
      ccn = "cd ${devTalon}/cursorless.nvim";
      ccl = "cd ${devTalon}/cursorless";
      ## nix
      cnc = "cd ${devNix}/nix-config";
      cnn = "cd ${devNix}/nixvim-flake";
      cns = "cd ${devNix}/nix-secrets";
      cnh = "cd ${devNix}/nixos-hardware";
      cnp = "cd ${devNix}/nixpkgs";

      ## rust cargo
      cr = "cargo run";
      ch = "cargo help";
      cb = "cargo build";
      cbr = "cargo build --release";
      ct = "cargo test";
      cf = "cargo fmt";

      # justfiles
      jr = "just rebuild";
      jrt = "just rebuild-trace";
      jl = "just --list";
      jc = "$just check";
      jct = "$just check-trace";

      # direnv
      da = "direnv allow";
      dr = "direnv reload";

      # prevent accidental killing of single characters
      pkill = "pkill -x";

      # easy disassembly
      dis-aarch64 = "r2 -q -a arm -b 64 -c 'pD'";
      dis-arm = "r2 -q -a arm -b 32 -c 'pD'";
      dis-x64 = "r2 -q -a x86 -b 64 -c 'pD'";
      dis-x86 = "r2 -q -a x86 -b 32 -c 'pD'";

      # systemctl services
      # NOTE: this kind of overlaps already with lots of sc-xxx aliases, so maybe revist
      s = "systemctl";
      sst = "systemctl status";
      sus = "systemctl --user status";
      sl = "systemctl list-units --type=service";
      sla = "systemctl list-units --all";
      sul = "systemctl --user list-units --type=service";
      sula = "systemctl --user list-units --all";
      sr = "systemctl restart";
      sur = "systemctl --user restart";

      # ssh
      sshnc = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null";
    };
  };
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
  };
}
