{
  config,
  osConfig,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  llmCfg = config.${namespace}.llm;
  cfg = config.${namespace}.llm.fabric;
  defaultProvider = lib.findFirst (p: p.name == llmCfg.defaultProvider) null llmCfg.providers;
  defaultModels = osConfig.${namespace}.services.llama-swap.defaultModels;

  # Populate fabric patterns from: official source, local repo, private repo
  mergedPatterns = pkgs.symlinkJoin {
    name = "merged-fabric-patterns";
    paths = [
      "${config.programs.fabric-ai.package.src}/data/patterns" # Default patterns from Nix pkg
      # ./XXX                   # Public patterns
      # inputs.nix-secrets.XXX  # Secret patterns
    ];
  };
in
{
  options.${namespace}.llm.fabric = {
    enable = lib.mkEnableOption "Enable AI client cli tooling";
  };
  config = lib.mkIf cfg.enable {
    home = {
      file = {
        ".config/fabric/.env".text = ''
          DEFAULT_MODEL="${llmCfg.defaultModel}"
          DEFAULT_MODEL="${defaultModels.${defaultProvider.name}.heavy}"
          DEFAULT_VENDOR="OpenAI"
          OPENAI_API_BASE_URL="https://llm.${defaultProvider.name}.${osConfig.hostSpec.domain}/v1"
          CUSTOM_PATTERNS_DIRECTORY="${config.home.homeDirectory}/.config/fabric/patterns"
          PATTERNS_LOADER_GIT_REPO_URL="https://github.com/danielmiessler/fabric.git"
          PATTERNS_LOADER_GIT_REPO_PATTERNS_FOLDER="patterns"
        '';
        ".config/fabric/openai_api_key".text = "foo";
        ".config/fabric/patterns/.keep".text = "# Managed by Home Manager";
      };

      activation.setupFabricPatterns = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        target="${config.home.homeDirectory}/.config/fabric/patterns"
        source="${mergedPatterns}"

        mkdir -p "$target"

        # Clear out any store-backed symlinks so they always refresh to current pattern set
        for item in "$target"/*; do
          if [ -L "$item" ]; then
            case "$(readlink "$item" || true)" in
              /nix/store/*) rm "$item" ;;
            esac
          fi
        done

        # Link all patterns
        if [ -d "$source" ]; then
          for item in "$source"/*; do
            name=$(basename "$item")
            dest="$target/$name"
            if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
              ln -s "$item" "$dest"
            fi
          done
        fi
      '';
    };

    programs = {
      # unix-style cli tool focusing on builtin patterns (prompts)
      fabric-ai = {
        enable = true;
        package = pkgs.unstable.fabric-ai;
        enableZshIntegration = true;
        # enablePatternsAliases = true;
      };
      zsh = {
        shellAliases = {
          "lgcm" = "_lgcm";
          "lgcs" = "_lgcs"; # staged diff -> commit message pushed into the next command line
          # "lgcS" = "git diff --cached | fabric -p git_staged_commit"; # Auto git commit single (all in one)
        };
        initContent =
          let
            gum = msg: ''gum spin --spinner dot --title "靈 ${msg}"'';
            # spinner + sh wrapper: streams output to the tty and passes the
            # function's args through (the `_` becomes sh's $0, the rest $1...)
            spin = msg: cmd: ''${gum msg} -- sh -c '${cmd} > /dev/tty' _ "$@"'';
            spinOut = msg: cmd: ''out="$(${gum msg} --show-output -- ${cmd})"'';
          in
          # bash
          ''
              _fabric_patterns() {
                local -a patterns
                # Split `fabric -l` on newlines; drop blanks and the "Found existing alias…"
                # notice (the only line with spaces).
                patterns=("''${(@f)$(fabric -l 2>/dev/null)}")
                patterns=(''${patterns:#'''})
                patterns=(''${patterns:#* *})
                (( ''${#patterns} )) || return
                _describe 'fabric patterns' patterns
              }

              _fabric() {
                local prev_idx=$((CURRENT - 1))
                if [[ ''${words[prev_idx]} == "-p" ]]; then
                  _fabric_patterns
                else
                  _default
                fi
              }
              compdef _fabric fabric

              # answer output to the terminal
              ling() {
                (( $# )) || { print -u2 -- "usage: ling <prompt>"; return 1; }
                ${spin "思考一下..." ''fabric -- "$@"''}
              }

              # answer pushed into the next command line
              lingx() {
                (( $# )) || { print -u2 -- "usage: lingx <prompt>"; return 1; }
                local out
                ${spinOut "靈: 思考一下..." ''fabric -- "$@"''}
                print -rz -- "$out"
              }

              # staged diff -> commit message pushed into the next command line
              _lgcs() {
                local out
                ${spinOut "Generating commit message..." "sh -c 'git diff --cached | fabric -p git_staged_commit'"}
                print -rz -- "$out"
              }

            _lgcm() {
                ${spin "Generating commit message..." "{ git diff; echo; git status --porcelain; } | fabric -p git_commit_multiple"}
              }
          '';
      };
    };
  };
}
