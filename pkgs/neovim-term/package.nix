{ pkgs }:
pkgs.writeShellScriptBin "neovim-term.sh" ''
  #!/usr/bin/env bash
  # NOTE: Don't use -u as NVIM is set from outside the script
  set -eo pipefail

  # IMPORTANT: talon title handling relies on the explicit zsh
  ${pkgs.nixcats}/bin/nvim -c ':term zsh'
''
