{ writeShellScriptBin, json5-jq }:
writeShellScriptBin "jq5" ''
  # Initialize arrays for options and query parts
  declare -a JQ_OPTS=()
  declare -a QUERY_PARTS=()

  # Collect arguments
  while [ $# -gt 1 ]; do
    if [[ $1 == -* ]]; then
      JQ_OPTS+=("$1")
    else
      QUERY_PARTS+=("$1")
    fi
    shift
  done

  # Last argument is always the file
  FILE="$1"

  # Join query parts with spaces
  QUERY="$(printf "%s " "''${QUERY_PARTS[@]}")"

  if [ ''${#QUERY_PARTS[@]} -eq 0 ]; then
    # No query case
    jq -Rs -L "${json5-jq}/share/" "''${JQ_OPTS[@]}" 'include "json5"; fromjson5' "$FILE"
  else
    # Query case
    jq -Rs -L "${json5-jq}/share/" "''${JQ_OPTS[@]}" "include \"json5\"; fromjson5 | $QUERY" "$FILE"
  fi
''
