{
  pkgs,
  lib,
  osConfig,
  secrets,
  ...
}:
{
  # All users get git no matter, what but additional settings may be added by
  # eg: development/git.nix, introdus
  home.packages = [
    pkgs.git-crypt # Needs to be global so talon dynamic lists work in repos with filters. FIXME: add a conditional?
    pkgs.delta # git diff tool
  ];

  programs.git = {
    package = pkgs.gitFull;
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
    ];

    # When using auth a yubikey should be used. But also, touching shouldn't be
    # required for repos that don't actually need auth. Solution is to ha sgrdcode
    # repos that require auth and default to ssh those only
    settings =
      let
        privateRepos = secrets.git.repos;
        privateWorkRepos = secrets.git.work.repos;

        insteadOfList =
          domain: urls:
          urls
          |> lib.map (url: {
            "ssh://git@${domain}/${url}" = {
              insteadOf = "https://${domain}/${url}";
            };
          });

        workRepoNames =
          lib.attrNames privateWorkRepos
          # nixfmt hack
          |> lib.optionals osConfig.hostSpec.isWork;

        workDomain =
          domain:
          lib.optionals (
            osConfig.hostSpec.isWork && (privateWorkRepos ? ${domain})
          ) privateWorkRepos.${domain};

        privateAlwaysSshRepos =
          (lib.attrNames privateRepos) ++ workRepoNames
          |> lib.map (domain: insteadOfList domain (privateRepos.${domain} ++ (workDomain domain)))
          |> lib.concatLists
          |> lib.foldl' lib.recursiveUpdate { };
      in
      {
        url = privateAlwaysSshRepos; # NOTE: See introdus/modules/home/git.nix for more
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
        core.pager = "delta";
        delta = {
          enable = true;
          features = [
            "side-by-side"
            "line-numbers"
            "hyperlinks"
            "line-numbers"
            "commit-decoration"
          ];
        };
        alias.edit = "!$EDITOR $(git status --porcelain | awk '{print $2}')";
      };
  };

  home.sessionVariables.GIT_EDITOR = osConfig.hostSpec.defaultEditor;
}
