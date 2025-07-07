{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
{
  # All users get git no matterwhat but additional settings may be added by eg: development.nix
  home.packages = [
    pkgs.git-crypt # Needs to be global so talon dynamic lists work in repos with filters
    pkgs.delta # git diff tool
  ];

  programs.git = {
    package = pkgs.gitAndTools.gitFull;
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

    # Anytime I use auth, I want to use my yubikey. But I don't want to always be having to touch it
    # for things that don't need it. So I have to hardcode repos that require auth, and default to ssh for
    # actions that require auth.
    extraConfig =
      let
        privateRepos = inputs.nix-secrets.git.repos;
        privateWorkRepos = inputs.nix-secrets.git.work.repos;
        insteadOfList =
          domain: urls:
          lib.map (url: {
            "ssh://git@${domain}/${url}" = {
              insteadOf = "https://${domain}/${url}";
            };
          }) urls;

        # FIXME: At the moment this requires personal and work sets to maintian lists fo git servers, even if
        # unneeded, so could also check if domain list actually exists in the set first.
        alwaysSshRepos = lib.foldl' lib.recursiveUpdate { } (
          lib.concatLists (
            lib.map
              (
                domain:
                insteadOfList domain (
                  privateRepos.${domain} ++ (lib.optionals config.hostSpec.isWork privateWorkRepos.${domain})
                )
              )
              (
                lib.attrNames privateRepos ++ lib.optionals config.hostSpec.isWork (lib.attrNames privateWorkRepos)
              )
          )
        );
      in
      {
        # Only force ssh if it's not an iso
        url =
          alwaysSshRepos
          // lib.optionalAttrs (!config.hostSpec.isMinimal) {
            "ssh://git@github.com" = {
              pushInsteadOf = [ "https://github.com" ];
            };
            "ssh://git@gitlab.com" = {
              pushInsteadOf = [ "https://gitlab.com" ];
            };
          };
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
      };
  };

  home.sessionVariables.GIT_EDITOR = if config.hostSpec.isServer then "nvim" else "code -w";
}
