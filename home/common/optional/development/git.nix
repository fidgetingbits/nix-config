{
  config,
  osConfig,
  lib,
  secrets,
  ...
}:
let
  home = config.home.homeDirectory;
in
{
  introdus.gitDev = {
    enable = true;
    keysPath = "hosts/common/users/super/keys/";
    # personal
    devFolders = [
      "${home}/dev/"
      "${home}/source/"
    ];
    devKeys = [
      "id_dade.pub"
      "id_dark.pub"
      "id_drzt.pub"
    ];
    devRepos = secrets.git.repos;

  }
  // lib.optionalAttrs osConfig.hostSpec.isWork {
    # work
    workKeys = [
      "id_dark.pub"
      "id_drzt.pub"
    ];
    workFolders = [
      "${home}/work/"
      "${home}/persist/work/"
    ];
    workServers = secrets.work.git.servers;
    workRepos = secrets.git.work.repos;
  };

  programs.git = {
    enable = true;
    ignores = [
      # nix
      "*.drv"
      "result"
      # rust
      "target/"
      # python
      "*.py?"
      "__pycache__/"
      ".venv/"
      # direnv
      ".direnv/"
      ".envrc"
    ];

    settings = {
      core.excludeFiles = builtins.toFile "global-gitignore" ''
        .DS_Store
        .DS_Store?
        ._*
        .Spotlight-V100
        .Trashes
        ehthumbs.db
        Thumbs.db
        node_modules
      '';
      core.attributesfile = builtins.toFile "global-gitattributes" ''
        Cargo.lock -diff
        flake.lock -diff
        *.drawio -diff
        *.svg -diff
        *.json diff=json
        *.bin diff=hex difftool=hex
        *.dat diff=hex difftool=hex
        *aarch64.bin diff=objdump-aarch64 difftool=objdump-aarch64
        *arm.bin diff=objdump-arm difftool=objdump-arm
        *x64.bin diff=objdump-x86_64 difftool=objdump-x64
        *x86.bin diff=objdump-x86 difftool=objdump-x86
      '';

      # FIXME: revisit this vs use of delta in common/core/git.nix
      diff.tool = "difftastic";
      difftool = {
        prompt = "false";
        difftastic.cmd = "difft \"$LOCAL\" \"$REMOTE\"";
      };

      # Makes single line json diffs easier to read
      diff.json.textconv = "jq --sort-keys .";
      # Makes binary diffs easier to read
      # Use --diff-algorithm=hex to override with hex if needed
      diff.hex.textconv = "hexyl -p";
      diff.hex.binary = true;
      diff.objdump-aarch64.textconv = "aarch64-unknown-linux-gnu-objdump -b binary -D -maarch64 | tr -s ' ' | cut -f3- -d ' '";
      diff.objdump-aarch64.binary = true;
      diff.objdump-arm.textconv = "armv7l-unknown-linux-gnueabihf-objdump -b binary -D -marm | tr -s ' ' | cut -f3- -d ' '";
      diff.objdump-arm.binary = true;
      diff.objdump-x86_64.textconv = "objdump -b binary -D -mi386:x86-64 -M intel | tr -s ' ' | cut -f3- -d ' '";
      diff.objdump-x86_64.binary = true;
      diff.objdump-x86.textconv = "objdump -b binary -D -mi386 -M intel | tr -s ' ' | cut -f3- -d ' '";
      diff.objdump-x86.binary = true;

      # Colored diff of hex files
      #difftool.hex.cmd = ''diff -u -w <(hexyl -p "$LOCAL") <(hexyl -p "$REMOTE") | delta --side-by-side'';
      # FIXME: Abstract this such that it can be used for all architectures
      #difftool.objdump-aarch64.cmd = ''
      #  echo "objdump" && temp_file1=$(mktemp) && \
      #  git show "$1" > "$temp_file1" && \
      #  temp_file2=$(mktemp) && \
      #  git show "$2" > "$temp_file2" && \
      #  diff -u -w \
      #    <(aarch64-unknown-linux-gnu-objdump -b binary -D -maarch64 "$temp_file1" | tr -s ' ' | cut -f3- -d ' ') \
      #    <(aarch64-unknown-linux-gnu-objdump -b binary -D -maarch64 "$temp_file2" | tr -s ' ' | cut -f3- -d ' ') | \
      #  delta --side-by-side; rm -f "$temp_file1" "$temp_file2"
      #'';
    };
  };
}
