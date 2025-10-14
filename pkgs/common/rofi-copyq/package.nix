{ writeShellScriptBin }:
writeShellScriptBin "rofi-copyq" ''
  #!/usr/bin/env bash
  # NOTE: Don't use -u as NVIM is set from outside the script
  set -eo pipefail

  copyq eval -- "for(i=0; i<size(); ++i) print(str(read(i)).replace(/\n/g, ' ')+'\n')" |\
  awk '{if(length() >= 2) print $0}' |\
  head -10 |\
  rofi -dmenu -format i -kb-row-up k -kb-row-down j -kb-select-1 1 -p clipboard |\
  xargs -I {} sh -c 'copyq select {}'
''
