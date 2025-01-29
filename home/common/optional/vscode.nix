{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  exts = inputs.nix-vscode-extensions.extensions.${pkgs.system}.vscode-marketplace;
  marketplace-extensions = builtins.attrValues {
    # Git
    inherit (exts.eamodio) gitlens; # Fancy git
    inherit (exts.mhutchie) git-graph; # Git graph
    inherit (exts.github) vscode-github-actions; # Github actions
    inherit (exts.github) vscode-pull-request-github; # Github PRs

    # Misc Linting
    inherit (exts.esbenp) prettier-vscode;
    inherit (exts.joshbolduc) commitlint;
    inherit (exts.usernamehw) errorlens; # Highlight errors inline
    inherit (exts.streetsidesoftware) code-spell-checker; # Spell checking

    # Themes
    inherit (exts.jdinhlife) gruvbox;
    inherit (exts.pkief) material-product-icons;
    inherit (exts.pkief) material-icon-theme;
    inherit (exts.qufiwefefwoyn) kanagawa;
    inherit (exts.catppuccin) catppuccin-vsc;
    inherit (exts.dracula-theme) theme-dracula;
    # sndst00m.markdown-github-dark-pack

    # UI Changes
    inherit (exts.visbydev) folder-path-color; # color folder names

    # C
    inherit (exts.xaver) clang-format; # C/C++ formatter
    inherit (exts.ms-vscode) cpptools-extension-pack;
    inherit (exts.llvm-vs-code-extensions) vscode-clangd; # C/C++ LSP

    # Rust
    inherit (exts.rust-lang) rust-analyzer; # Rust LSP

    # Lua
    inherit (exts.sumneko) lua; # lua lsp;
    inherit (exts.johnnymorganz) stylua; # lua linting

    # Talon
    inherit (exts.pokey) parse-tree; # cursorless tree-sitter dependency
    inherit (exts.pokey) command-server; # talon -> vscode IPC
    # NOTE: We use our own copy of this atm, see justfile
    # inherit (exts.pokey) cursorless; # core cursorless
    inherit (exts.andreasarvidsson) andreas-talon; # talon helpers
    inherit (exts.wenkokke) talonfmt-vscode; # talon formatter
    inherit (exts.paulschaaf) talon-filetree; # dictate files sidebar
    inherit (exts.rioj7) select-by; # used for grow/shrink commands
    inherit (exts.mrob95) vscode-talonscript; # syntax highlighting
    inherit (exts.sleistner) vscode-fileutils; # fileutils.renameFile

    # Cursorless Development
    inherit (exts.editorconfig) editorconfig; # Allows vscode setting overrides
    inherit (exts.jrieken) vscode-tree-sitter-query;
    inherit (exts.charliermarsh) ruff; # python linting
    inherit (exts.dbaeumer) vscode-eslint; # javascript/typescript linting

    # Json
    inherit (exts.zainchen) json; # Adds json sidebar
    inherit (exts.mohsen1) prettify-json;

    # Justfiles
    inherit (exts.skellock) just;

    # CMake
    inherit (exts.twxs) cmake;

    # GDB

    # Makefile
    inherit (exts.ms-vscode) makefile-tools;

    # Shellscript
    inherit (exts.foxundermoon) shell-format;
    inherit (exts.timonwong) shellcheck;

    # toml
    inherit (exts.tamasfe) even-better-toml;

    # Nix
    # Broken for flakes
    # arrterian.nix-env-selector # Allow .envrc to select nix environments
    inherit (exts.jnoortheen) nix-ide; # Syntax highlighting, LSP, etc

    # Python
    inherit (exts.ms-python) python;
    inherit (exts.ms-python) vscode-pylance; # Python LSP
    inherit (exts.donjayamanne) python-environment-manager; # Manage python environments

    # Markdown
    inherit (exts.yzhang) markdown-all-in-one; # Markdown helpers
    inherit (exts.davidanson) vscode-markdownlint; # Markdown linter

    # CSV
    inherit (exts.mechatroner) rainbow-csv; # CSV linter, syntax highlighting

    # Javascript / Typescript
    inherit (exts.rvest) vs-code-prettier-eslint; # javascript/typescript
    #dbaeumer.vscode-eslint

    # Apache
    inherit (exts.mrmlnc) vscode-apache; # Apache syntax highlighting

    # PDF
    inherit (exts.tomoki1207) pdf;

    # gitconfig
    inherit (exts.yy0931) gitconfig-lsp;

    # Utility
    inherit (exts.silesky) toggle-boolean; # Toggles antonyms
    inherit (exts.github) copilot copilot-chat; # AI coding
    inherit (exts.will-wow) vscode-alternate-file; # Toggle between header/source files using .projection.json files
    inherit (exts.arturodent) jump-and-select; # Navigation like vim f-key
    inherit (exts.ms-vscode) hexeditor; # Hex editor
    inherit (exts.yechunan) json-color-token; # Colorize json tokens (or any language)

    inherit (exts.mkhl) direnv; # Auto environment entry
    inherit (exts.stkb) rewrap; # Auto wrap and custom cursorless actions
    inherit (exts.attilathedud) data-converter; # Convert between data formats (dec, hex, binary, etc)

    # Documentation
    inherit (exts.meronz) manpages; # man page opening

    # UX
    inherit (exts.alefragnani) bookmarks; # Bookmark jumping
    # WARNING: This conflicts with cursorless hats too much
    # wayou.vscode-todo-highlight # Highlight TODOs
    inherit (exts.johnpapa) vscode-peacock; # per-workspace color themes
    # WARNING: These cause quite weird cursorless interactions
    # asvetliakov.vscode-neovim
    # vscodevim.vim # Vim-style
    inherit (exts.koalamer) workspace-in-status-bar;
    inherit (exts.tonybaloney) vscode-pets; # essentials

    # Syntax and File Detection
    inherit (exts.pierre-payen) gdb-syntax;

    # Remote Development
    inherit (exts.ms-vscode-remote)
      remote-ssh # ssh remote development
      remote-ssh-edit
      ; # ssh config syntax highlighting, etc

    # VSCode Automation
    inherit (exts.usernamehw) commands;

    # Assembly
    # pkgs.vscode-extensions."64kramsystem".markdown-code-blocks-asm-syntax-highlighting
    inherit (exts.dan-c-underwood) arm;
    inherit (exts."13xforever") language-x86-64-assembly;

  };
in
# FIXME(organize): Try to get ryan4yin's way working with genPlatformArgs eventually
{
  programs.vscode = {
    enable = true;
    package = pkgs.unstable.vscode;
    mutableExtensionsDir = true;
    enableUpdateCheck = false;
    enableExtensionUpdateCheck = false;
    extensions =
      (builtins.attrValues {
        inherit (exts.bbenoist)
          nix # Nix file detection
          ;
      })
      ++ marketplace-extensions;

    # IMPORTANT: You must wrap dotted things in quotes, because nix will
    # naturally expand them into a hierarchy, whereas the settings json
    # expects them to be explicit key names
    userSettings =
      let
        # cursorlessGruvboxDarkColors = {
        #   default = "#A89984";
        #   blue = "#458588";
        #   green = "#36B33F";
        #   # green = "#B8BB26";
        #   red = "#FB4934";
        #   # pink = "#D3869B";
        #   pink = "#E06CAA";
        #   # yellow = "#FABD2F";
        #   yellow = "#E5C02C";
        #   userColor1 = "#89B482";
        #   userColor2 = "#FFFFFF";
        # };
        # https://html-color.codes and https://draculatheme.com/contribute
        cursorlessDraculaColors = {
          default = "#708090";
          blue = "#0067ce";
          green = "#50FA7B";
          red = "#FF5555";
          pink = "#FF79C6";
          yellow = "#F1FA8C";
          # userColor1 = "#8BE9FD"; # cyan
          userColor1 = "#35cef0"; # cyan
          userColor2 = "#F8F8F2"; # white
        };
      in
      {
        "codeQL.telemetry.enableTelemetry" = false;
        "breadcrumbs.enabled" = false;
        "emmet.useInlineCompletions" = true;
        "security.workspace.trust.enabled" = false;

        "diffEditor.ignoreTrimWhitespace" = false;
        # "gruvboxMaterial.darkWorkbench" = "flat";
        # vim.startInInsertMode = true;
        "search.mode" = "reuseEditor";
        "debug.onTaskErrors" = "debugAnyway";
        "workbench.colorCustomizations" = {
          "editorUnnecessaryCode.opacity" = "#000000FF"; # Prevent dimming which impacts cursorless
          "editorUnnecessaryCode.border" = cursorlessDraculaColors.red;
          # This doesn't work in practice, may be overridden by stylix
          # "editorWhiteSpace.foreground" = "#FFFFFF80"; # Force dimming which makes white space jump out less obvious
        };
        update.mode = "none";
        "github.copilot.editor.enableAutoCompletions" = true;
        "direnv.path.executable" = lib.getExe pkgs.direnv;

        # vscode-neovim.neovimExecutablePaths.linux = "/usr/bin/nvim";
        # Avoid spam from the neovim extension
        # extensions.experimental.affinity = {
        #   "asvetliakov.vscode-neovim" = 1;
        # };

        "[apacheconf]".editor.defaultFormatter = "esbenp.prettier-vscode";
        "[c]".editor.defaultFormatter = "xaver.clang-format";
        "[cpp]".editor.defaultFormatter = "xaver.clang-format";
        "C_Cpp.inactiveRegionOpacity" = 1; # Prevent dimming which impacts cursorless

        "[css]".editor.defaultFormatter = "esbenp.prettier-vscode";
        "[html]".editor.defaultFormatter = "esbenp.prettier-vscode";
        "[javascript]".editor.defaultFormatter = "rvest.vs-code-prettier-eslint";
        "[json]".editor.defaultFormatter = "esbenp.prettier-vscode";
        "[jsonc]".editor.defaultFormatter = "rvest.vs-code-prettier-eslint";

        "[rust]".editor.defaultFormatter = "rust-lang.rust-analyzer";
        "rust-analyzer.check.command" = "clippy";
        "rust-analyzer.files.excludeDirs" = [ ".direnv" ];
        # I get a disruptive warning: proc-macro crate is missing build data, so I'm disabling this for now
        "rust-analyzer.procMacro.enable" = false;

        "[lua]".editor.defaultFormatter = "johnnymorganz.stylua";
        "stylua.styluaPath" = lib.getExe pkgs.stylua;

        "[nix]".editor.defaultFormatter = "jnoortheen.nix-ide";

        # This is for .git/config
        "[properties]".editor.defaultFormatter = "yy0931.gitconfig-lsp";
        "[scss]".editor.defaultFormatter = "sibiraj-s.vscode-scss-formatter";
        "[typescript]".editor.defaultFormatter = "rvest.vs-code-prettier-eslint";

        "[python]" = {
          editor.defaultFormatter = "charliermarsh.ruff";
          editor.formatOnType = true;
        };

        "[markdown]" = {
          editor.wordWrap = "wordWrapColumn";
          editor.formatOnSave = false;
          editor.defaultFormatter = "yzhang.markdown-all-in-one";
        };
        "files.defaultLanguage" = "markdown";

        # FIXME: Does this work for regular make files?
        "[makefile]" = {
          editor.defaultFormatter = "twxs.cmake";
          editor.formatOnSave = true;
          editor.insertSpaces = false;
        };

        # FIXME: nix uses shell check, so we may want to switch to that? Or at least configure them to behave the same
        "[shellscript]" = {
          editor.defaultFormatter = "foxundermoon.shell-format";
          editor.formatOnSave = true;
        };
        shellformat.path = lib.getExe pkgs.shfmt;
        # Explicit to drop dockerfile, which breaks due to a bug https://github.com/foxundermoon/vs-shell-format/issues/304
        "shellformat.effectLanguages" = [
          "shellscript"
          "dotenv"
          "hosts"
          "jvmoptions"
          "ignore"
          "gitignore"
          "properties"
          "spring-boot-properties"
          "azcli"
          "bats"
        ];

        converter.prependDataWithIdentifier = true;

        # FIXME: This path needs to be tweaked
        # "Lua.workspace.library" = [
        #   "/home/aa/public/source/neovim/core/neovim/runtime/lua/vim/runtime/lua"
        # ];
        "cursorless.debug" = true;
        "cursorless.commandHistory" = true;
        "cursorless.hatEnablement.shapes" = {
          "bolt" = true;
          "curve" = true;
          "fox" = true;
          "frame" = true;
          "play" = true;
          "wing" = true;
          "hole" = true;
          "ex" = true;
          "crosshairs" = true;
          "eye" = true;
        };
        "cursorless.experimental.hatStability" = "stable";
        "cursorless.hatPenalties.shapes" = {
          "bolt" = 1;
          "curve" = 2;
          "frame" = 2;
          "hole" = 3;
          "ex" = 2;
          "crosshairs" = 4;
          "eye" = 3;
        };
        "cursorless.hatEnablement.colors" = {
          "userColor1" = true;
          "userColor2" = true;
        };
        "cursorless.experimental.snippetsDir" =
          "${config.home.homeDirectory}/.talon/user/private/settings/cursorless-snippets";
        # FIXME:Tweak these colors to match stylix somehow
        "cursorless.colors.dark" = cursorlessDraculaColors;
        "cursorless.colors.light" = cursorlessDraculaColors;
        "cursorless.individualHatAdjustments" = {
          "default" = {
            "sizeAdjustment" = 20;
            "verticalOffset" = 10;
          };
          "ex" = {
            "sizeAdjustment" = 0;
            "verticalOffset" = 10;
          };
          "fox" = {
            "sizeAdjustment" = 0;
            "verticalOffset" = 10;
          };
          "wing" = {
            "sizeAdjustment" = 0;
            "verticalOffset" = 10;
          };
          "hole" = {
            "sizeAdjustment" = 0;
            "verticalOffset" = 10;
          };
          "frame" = {
            "sizeAdjustment" = 0;
            "verticalOffset" = 10;
          };
          "curve" = {
            "sizeAdjustment" = 0;
            "verticalOffset" = 10;
          };
          "eye" = {
            "sizeAdjustment" = 0;
            "verticalOffset" = 10;
          };
          "play" = {
            "sizeAdjustment" = 0;
            "verticalOffset" = 10;
          };
          "bolt" = {
            "sizeAdjustment" = 0;
            "verticalOffset" = 10;
          };
          "crosshairs" = {
            "sizeAdjustment" = 0;
            "verticalOffset" = 10;
          };
        };

        editor = {
          accessibilitySupport = "off";
          autoClosingBrackets = "never";
          autoClosingQuotes = "never";
          autoSurround = "never";
          cursorBlinking = "smooth";
          cursorSmoothCaretAnimation = "on";
          cursorWidth = 2;
          find.addExtraSpaceOnTop = false;
          fontFamily = "'Meslo LGS NF', 'monospace', monospace";
          fontSize = 14;
          formatOnSave = true;
          # If true, this messes up lots of text when passing, like '-p' will become '- p', etc.
          formatOnPaste = false;
          hover.enabled = false;
          inlayHints.enabled = "off";
          inlineSuggest.enabled = true;
          largeFileOptimizations = false;
          lineNumbers = "on";
          linkedEditing = true;
          lineHeight = 1.8;
          maxTokenizationLineLength = 60000;
          minimap.enabled = false;
          overviewRulerBorder = false;
          quickSuggestions.strings = true;
          rulers = [ 120 ];

          # Used to use`` boundary, but I found it to busy with cursorless, so now I only use it on selection
          renderWhitespace = "selection";
          renderLineHighlight = "all";
          smoothScrolling = true;
          suggest.showStatusBar = true;
          suggestSelection = "first";
          wordWrapColumn = 120;
          bracketPairColorization = {
            enabled = true;
            independentColorPoolPerBracketType = true;
          };

          guides = {
            bracketPairs = true;
            indentation = true;
          };
          stickyScroll.enabled = true; # Keep context above the fold
          stickyScroll.maxLineCount = 10;
        };

        "explorer" = {
          confirmDragAndDrop = false;
          confirmDelete = true;
        };

        # These don't seem to work broken out.
        extensions.autoUpdate = false;
        extensions.autoCheckUpdates = false;

        "files" = {
          eol = "\n";
          insertFinalNewline = true;
          trimTrailingWhitespace = true;
        };

        git = {
          "autofetch" = true;
          "confirmSync" = false;
          "enableSmartCommit" = true;
        };

        "github.copilot.enable" = {
          "*" = true;
          "scminput" = false;
          editor.enableAutoCompletions = true;
        };
        "github.copilot.advanced" = { };
        "github.copilot.config.codeGeneration.instructions" = [
          {
            "file" = "${config.home.homeDirectory}/.config/vscode/copilot_prompt";
          }
        ];
        "github.chat.config.codeGeneration.instructions" = [
          {
            "file" = "${config.home.homeDirectory}/.config/vscode/copilot_prompt";
          }
        ];

        "gitlens.currentLine.enabled" = false;
        "gitlens.hovers.currentLine.over" = "line";
        "gitlens.mode.active" = "review";
        "gitlens.ai.experimental.provider" = "openai";
        "gitlens.telemetry.enabled" = false;

        # Stop annoying prompts, as usually I don't want to open them.
        "git.openRepositoryInParentFolders" = "never";

        "telemetry.enableCrashReporter" = false;
        "telemetry.enableTelemetry" = false;
        "telemetry.telemetryLevel" = "off"; # This should cover the above, but meh

        "peacock.favoriteColors" = [
          {
            name = "Angular Red";
            value = "#dd0531";
          }
          {
            name = "Azure Blue";
            value = "#007fff";
          }
          {
            name = "JavaScript Yellow";
            value = "#f9e64f";
          }
          {
            name = "Mandalorian Blue";
            value = "#1857a4";
          }
          {
            name = "Node Green";
            value = "#215732";
          }
          {
            name = "React Blue";
            value = "#61dafb";
          }
          {
            name = "Something Different";
            value = "#832561";
          }
          {
            name = "Svelte Orange";
            value = "#ff3d00";
          }
          {
            name = "Vue Green";
            value = "#42b883";
          }
        ];

        "jsonColorToken.colorTokenCasing" = "Lowercase";
        "jsonColorToken.languages" = [
          "bat"
          "blade"
          "c"
          "css"
          "csharp"
          "cpp"
          "csv"
          "dart"
          "dialog"
          "env"
          "go"
          "hlsl"
          "html"
          "handlebars"
          "ini"
          "json"
          "jsonc"
          "java"
          "javascript"
          "javascriptreact"
          "julia"
          "lua"
          "makefile"
          "markdown"
          "nix"
          "objective-c"
          "objective-cpp"
          "php"
          "perl"
          "perl6"
          "plaintext"
          "powershell"
          "properties"
          "jade"
          "python"
          "r"
          "razor"
          "ruby"
          # "rust" # conflicts to much with hex format strings
          "spwn"
          "shaderlab"
          "shellscript"
          "svelte"
          "swift"
          "toml"
          "typescript"
          "typescriptreact"
          "vue"
          "xml"
          "yaml"
        ];

        "rewrap.autoWrap.enabled" = true;
        "rewrap.wrappingColumn" = 120;
        terminal.integrated = {
          cursorBlinking = true;
          cursorStyle = "line";
          cursorWidth = 2;
          fontFamily = "'monosMesloLGS NFpace'";
          fontSize = 16;
          smoothScrolling = true;
          # Make cursorless work when terminal focused: https://github.com/pokey/command-server/issues/14
          commandsToSkipShell = [ "command-server.runCommand" ];
        };
        "toggleboolean.mapping" = {
          "0" = 1;
          "1" = 0;
          "true" = false;
          "false" = true;
          "yes" = "no";
          "no" = "yes";
          "on" = "off";
          "off" = "on";
          "up" = "down";
          "down" = "up";
          "left" = "right";
          "right" = "left";
          "+" = "-";
          "-" = "+";
          "(" = ")";
          ")" = "(";
          "[" = "]";
          "]" = "[";
          "{" = "}";
          "}" = "{";
          "<" = ">";
          ">" = "<";
          "enabled" = "disabled";
          "disabled" = "enabled";
          "active" = "inactive";
          "inactive" = "active";
          "read" = "write";
          "write" = "read";
          "start" = "stop";
          "stop" = "start";
          "open" = "close";
          "close" = "open";
          "first" = "last";
          "last" = "first";
          "get" = "set";
          "set" = "get";
          "large" = "small";
          "small" = "large";
          "parent" = "child";
          "child" = "parent";
          "valid" = "invalid";
          "invalid" = "valid";
          "push" = "pop";
          "pop" = "push";
          "before" = "after";
          "after" = "before";
          "input" = "output";
          "output" = "input";
          "top" = "bottom";
          "bottom" = "top";
          "some" = "none";
          "none" = "some";
          "high" = "low";
          "low" = "high";
          "client" = "server";
          "server" = "client";
          "master" = "slave";
          "slave" = "master";
          "compress" = "decompress";
          "decompress" = "compress";
          "public" = "private";
          "private" = "public";
          "visible" = "hidden";
          "hidden" = "visible";
          "old" = "new";
          "new" = "old";
          "show" = "hide";
          "hide" = "show";
        };

        "window" = {
          menuBarVisibility = "classic";
          nativeTabs = true;
          titleBarStyle = "custom";
          zoomLevel = 1;
          title = ''
            ''${dirty}filename:''${activeEditorShort}''${separator}''${rootName}''${separator}''${profileName}''${separator}''${appName}''${separator}''${focusedView}
          '';
        };

        # This seems to spam settings.json change attempts on open, when it's already set in the
        # entry below, so has to be set independently
        "workbench.editor.tabActionLocation" = "left";

        "workbench" = {
          externalBrowser = "firefox"; # FIXME: make this use a system wide browser config value
          startupEditor = "none";

          # Theming manage globally by stylix
          # colorTheme = "Gruvbox Dark Soft";
          # colorTheme = "Dracula Theme";
          iconTheme = "material-icon-theme";
          productIconTheme = "material-product-icons";

          # UX
          editor.tabCloseButton = "left";
          editor.highlightModifiedTabs = true;

          editor.wrapTabs = true;
          list.smoothScrolling = true;
          panel.defaultLocation = "bottom";
          smoothScrolling = true;

          # File tree
          tree.enableStickyScroll = true;
          tree.stickyScrollMaxItemCount = 5;
        };

        "zenMode" = {
          hideTabs = false;
          hideLineNumbers = false;
        };
        "rust-analyzer.links.preferredBrowser" = "firefox";

        # FIXME(vscode): This variable escaping is busted, so I'm just ignoring for now
        # "workbench.editor.customLabels.patterns" = {
        #   "**/default.nix" = "''${dirname}/default.''${extname}";
        # };
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "${lib.getBin pkgs.nil}/bin/nil";
        "nix.serverSettings" = {
          "nil" = {
            "formatting" = {
              "command" = [ "${lib.getBin pkgs.unstable.nixfmt-rfc-style}/bin/nixfmt" ];
            };
            #          "diagnostics" = {
            #"ignored" = [ "unused_binding" "unused_with" ];
            #};
          };
          "nixd" = {
            formatting = {
              command = [ "${lib.getBin pkgs.unstable.nixfmt-rfc-style}/bin/nixfmt" ];
            };
            options =
              let
                flakeRoot = lib.custom.relativeToRoot "./.";
              in
              {
                nixos = {
                  expr = ''
                    let configs = (builtins.getFlake ${flakeRoot}).nixosConfigurations;
                    in (builtins.head (builtins.attrValues configs)).options
                  '';
                };
                home_manager = {
                  expr = ''
                    let configs = (builtins.getFlake ${flakeRoot}).homeConfigurations;
                    in (builtins.head (builtins.attrValues configs)).options
                  '';
                };
                darwin = {
                  expr = ''
                    let configs = (builtins.getFlake ${flakeRoot}).darwinConfigurations;
                    in (builtins.head (builtins.attrValues configs)).options
                  '';
                };
              };
          };
        };

      };
  };

  # Prevent keystore errors
  home.file.".vscode/argv.json" = {
    force = true;
    text = ''
      {
      	// "disable-hardware-acceleration": true,
      	"enable-crash-reporter": false,
      	// Unique id used for correlating crash reports sent from this instance.
      	// Do not edit this value.
      	"crash-reporter-id": "e9dfe01e-e6e1-4237-b2f2-a153ad5e5aa0",
        "password-store": "gnome",
        "force-renderer-accessibility": false
      }
    '';
  };
  # This is to prevent a bug with extensions being disabled when rebuilding nix with a new extension
  home.file.".vscode/extensions/.obsolete" = {
    force = true;
    text = ''{}'';
  };

  # FIXME(vscode): add an xdg-open override for opening inside the current vscode instance
  # https://github.com/tljuniper/dotfiles/blob/635635ed7c2eaf1a543081f452a5c0953db91ae7/home/desktop/vscode.nix#L152

}
