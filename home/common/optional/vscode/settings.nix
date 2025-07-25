# IMPORTANT: You must wrap dotted things in quotes, because nix will
# naturally expand them into a hierarchy, whereas the settings json
# expects them to be explicit key names
{
  config,
  lib,
  pkgs,
}:
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
  "github.copilot.nextEditSuggestions.enabled" = true;
  # add recently edited files to the context of questions
  "github.copilot.chat.editor.temporalContext.enabled" = true;

  # always suggest at its below the line
  "editor.inlineSuggest.edits.renderSideBySide" = false;
  # auto accepting copilot changes
  # chat.editing.autoAcceptDelay = 10;
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

  # FIXME: This should be tied to voiceCoding being enabled
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
  # FIXME: Tweak these colors to match stylix somehow
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
    lineHeight = if config.hostSpec.voiceCoding then 1.8 else 0;
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

  # github
  "github.copilot.enable" = {
    "*" = true;
    "scminput" = false;
    editor.enableAutoCompletions = true;
  };
  "github.copilot.advanced" = { };
  "github.copilot.chat.codeGeneration.useInstructionFiles" = true;

  #  "github.copilot.config.codeGeneration.instructions" = [
  #    {
  #      "file" = "${config.home.homeDirectory}/.config/vscode/copilot_prompt";
  #    }
  #  ];
  #  "github.chat.config.codeGeneration.instructions" = [
  #    {
  #      "file" = "${config.home.homeDirectory}/.config/vscode/copilot_prompt";
  #    }
  #  ];

  # gitlab
  "gitlab.duoCodeSuggestions.enabled" = false;
  "gitlab.duoChat.enabled" = false;
  "gitlab.duo.enabledWithoutGitlabProject" = false;
  "gitlab.real-timeSecurityScan.scanFileOnSave" = false;

  # gitlens
  "gitlens.currentLine.enabled" = false;
  "gitlens.hovers.currentLine.over" = "line";
  "gitlens.mode.active" = "review";
  "gitlens.ai.experimental.provider" = "openai";
  "gitlens.telemetry.enabled" = false;

  # Stop annoying prompts, as usually I don't want to open them.
  "git.openRepositoryInParentFolders" = "never";

  # telemetry
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
  # Anything commented out is because conflicts to much with hex format strings
  "jsonColorToken.languages" = [
    "bat"
    "blade"
    # "c"
    "css"
    # "csharp"
    # "cpp"
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
    # "lua"
    "makefile"
    "markdown"
    "nix"
    # "objective-c"
    # "objective-cpp"
    "php"
    "perl"
    "perl6"
    "plaintext"
    "powershell"
    "properties"
    "jade"
    # "python"
    "r"
    "razor"
    "ruby"
    # "rust"
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
    externalBrowser = config.hostSpec.defaultBrowser;
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
  "rust-analyzer.links.preferredBrowser" = config.hostSpec.defaultBrowser;

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

  # Performance: Exclude directories from file watching, search, and the explorer
  # to reduce CPU and memory usage
  "files.exclude" = {
    "**/.git" = true;
    "**/node_modules" = true;
    "**/dist" = true;
    "**/build" = true;
    "**/tmp" = true;
    "**/.direnv" = true;
    "**/result" = true; # Nix build results
    "**/result-*" = true; # Nix build results
    "**/.venv" = true; # Python virtual environments
    "**/venv" = true;
    "**/__pycache__" = true;
  };
  "files.watcherExclude" = {
    "**/.git/objects/**" = true;
    "**/.git/subtree-cache/**" = true;
    "**/node_modules/**" = true;
    "**/dist/**" = true;
    "**/build/**" = true;
    "**/tmp/**" = true;
    "**/.direnv/**" = true;
    "**/result" = true;
    "**/result-*" = true;
    "**/.venv/**" = true;
    "**/venv/**" = true;
    "**/__pycache__/**" = true;
  };
  "search.exclude" = {
    "**/.git" = true;
    "**/node_modules" = true;
    "**/dist" = true;
    "**/build" = true;
    "**/tmp" = true;
    "**/.direnv" = true;
    "**/result" = true;
    "**/result-*" = true;
    "**/.venv" = true;
    "**/venv" = true;
    "**/__pycache__" = true;
  };

  "search.followSymlinks" = false;
  "typescript.tsserver.log" = "off";
  "git.autofetch" = false;

  # Allow vscode quick open to work if vscodevim is enabled
  "vim.handleKeys" = {
    "<C-p>" = false;
  };
}
