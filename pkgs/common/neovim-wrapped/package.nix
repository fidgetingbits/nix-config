{ pkgs }:
pkgs.writeShellScriptBin "neovim.sh" ''
  #!/usr/bin/env bash
  # NOTE: Don't use -u as NVIM and SSH_CLIENT are set from outside the script
  set -eo pipefail

  # Run native vim if there is no RPC, or if we are in a SSH session
  if [ -z "''${NVIM}" ] || [ -v "''${SSH_CLIENT}" ];
  then
      ${pkgs.neovim}/bin/nvim "$@"
  else
      ${pkgs.neovim-python-scripts}/bin/neovim-openfile "$@"
  fi
''
