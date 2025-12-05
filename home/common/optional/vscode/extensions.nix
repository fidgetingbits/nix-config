{ inputs, pkgs, ... }:
let
  exts =
    inputs.nix-vscode-extensions.extensions.${pkgs.stdenv.hostPlatform.system}.vscode-marketplace;
in
lib.attrValues {
  # Git
  #inherit (exts.eamodio) gitlens; # Fancy git
  #inherit (exts.mhutchie) git-graph; # Git graph
  #    inherit (exts.github) vscode-github-actions; # Github actions
  #    inherit (exts.github) vscode-pull-request-github; # Github PRs
  #    inherit (exts.gitlab) gitlab-workflow; # Gitlab workflow

  # Misc Linting
  inherit (exts.esbenp) prettier-vscode;
  inherit (exts.joshbolduc) commitlint;
  inherit (exts.usernamehw) errorlens; # Highlight errors inline
  #    inherit (exts.streetsidesoftware) code-spell-checker; # Spell checking

  # Themes
  #    inherit (exts.jdinhlife) gruvbox;
  inherit (exts.pkief) material-product-icons;
  inherit (exts.pkief) material-icon-theme;
  #    inherit (exts.qufiwefefwoyn) kanagawa;
  #    inherit (exts.catppuccin) catppuccin-vsc;
  inherit (exts.dracula-theme) theme-dracula;
  # sndst00m.markdown-github-dark-pack

  # UI Changes
  #    inherit (exts.visbydev) folder-path-color; # color folder names

  # C
  inherit (exts.xaver) clang-format; # C/C++ formatter
  inherit (exts.ms-vscode) cpptools-extension-pack;
  inherit (exts.llvm-vs-code-extensions) vscode-clangd; # C/C++ LSP

  # Rust
  inherit (exts.rust-lang) rust-analyzer; # Rust LSP

  # Lua
  # FIXME: busted 2025-03-04
  #inherit (exts.sumneko) lua; # lua lsp;
  inherit (exts.johnnymorganz) stylua; # lua linting

  # Talon
  # inherit (exts.pokey) parse-tree; # cursorless tree-sitter dependency
  # inherit (exts.pokey) command-server; # talon -> vscode IPC
  # NOTE: We use our own copy of this atm, see justfile
  # inherit (exts.pokey) cursorless; # core cursorless
  #    inherit (exts.andreasarvidsson) andreas-talon; # talon helpers
  #    inherit (exts.wenkokke) talonfmt-vscode; # talon formatter
  #    inherit (exts.paulschaaf) talon-filetree; # dictate files sidebar
  #    inherit (exts.rioj7) select-by; # used for grow/shrink commands
  #    inherit (exts.mrob95) vscode-talonscript; # syntax highlighting
  #    inherit (exts.sleistner) vscode-fileutils; # fileutils.renameFile

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
  #    inherit (exts.twxs) cmake;

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
  inherit (exts.bbenoist)
    nix
    ; # Nix file detection
  # Python
  inherit (exts.ms-python) python;
  inherit (exts.ms-python) vscode-pylance; # Python LSP
  inherit (exts.donjayamanne) python-environment-manager; # Manage python environments

  # Markdown
  inherit (exts.yzhang) markdown-all-in-one; # Markdown helpers
  inherit (exts.davidanson) vscode-markdownlint; # Markdown linter

  # ReStructuredText (rst)
  #    inherit (exts.lextudio) restructuredtext;

  # CSV
  #    inherit (exts.mechatroner) rainbow-csv; # CSV linter, syntax highlighting

  # Javascript / Typescript
  inherit (exts.rvest) vs-code-prettier-eslint; # javascript/typescript
  #dbaeumer.vscode-eslint

  # Apache
  #    inherit (exts.mrmlnc) vscode-apache; # Apache syntax highlighting

  # PDF
  #    inherit (exts.tomoki1207) pdf;

  # gitconfig
  inherit (exts.yy0931) gitconfig-lsp;

  # Utility
  inherit (exts.silesky) toggle-boolean; # Toggles antonyms
  inherit (exts.github) copilot copilot-chat; # AI coding
  inherit (exts.will-wow) vscode-alternate-file; # Toggle between header/source files using .projection.json files
  inherit (exts.arturodent) jump-and-select; # Navigation like vim f-key
  inherit (exts.ms-vscode) hexeditor; # Hex editor
  #    inherit (exts.yechunan) json-color-token; # Colorize json tokens (or any language)

  # neovim
  #    inherit (exts.asvetliakov) vscode-neovim; # neovim integration (not vscodevim so we can use lua plugins)

  #    inherit (exts.mkhl) direnv; # Auto environment entry
  # inherit (exts.stkb) rewrap; # Auto wrap and custom cursorless actions
  # inherit (exts.attilathedud) data-converter; # Convert between data formats (dec, hex, binary, etc)

  # Documentation
  # inherit (exts.meronz) manpages; # man page opening

  # UX
  inherit (exts.alefragnani) bookmarks; # Bookmark jumping
  # WARNING: This conflicts with cursorless hats too much
  # wayou.vscode-todo-highlight # Highlight TODOs
  #    inherit (exts.johnpapa) vscode-peacock; # per-workspace color themes
  # WARNING: These cause quite weird cursorless interactions
  # asvetliakov.vscode-neovim
  # vscodevim.vim # Vim-style
  inherit (exts.koalamer) workspace-in-status-bar;
  #    inherit (exts.tonybaloney) vscode-pets; # essentials
  #    inherit (exts.joshmu) periscope; # neovim telescope-style picker
  #    inherit (exts.jpcrs) binocular; # neovim telescope-style picker
  #    inherit (exts.tomrijndorp) find-it-faster; # Find files faster (telescope-style but in terminal view)
  inherit (exts.ms-vscode-remote) vscode-remote-extensionpack; # Remote development (ssh, etc)

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
  #    inherit (exts.dan-c-underwood) arm;
  #    inherit (exts."13xforever") language-x86-64-assembly;

}
