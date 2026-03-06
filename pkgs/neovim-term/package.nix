{
  pkgs,
  lib,
  config,
}:
pkgs.writeShellScriptBin "neovim-term.sh" ''
  #!/usr/bin/env bash
  # NOTE: Don't use -u as NVIM is set from outside the script
  set -eo pipefail

  # IMPORTANT: talon title handling relies on the explicit zsh
  ${lib.getExe config.wrappers.neovim.wrapper} -c ':term zsh'

''
