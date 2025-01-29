{
  inputs,
  system,
  pkgs,
  ...
}:
{
  bats-test =
    pkgs.runCommand "bats-test"
      {
        buildInputs = [ pkgs.bats ];
      }
      ''
        bats tests
        touch $out
      '';

  pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
    src = ./.;
    default_stages = [ "pre-commit" ];
    hooks = {
      # General
      check-added-large-files.enable = true;
      check-case-conflicts.enable = true;
      check-executables-have-shebangs.enable = true;
      check-shebang-scripts-are-executable.enable = false;
      check-merge-conflicts.enable = true;
      # detect-private-keys.enable = true; # NOTE: This conflicts with us using git-crypt now, as the key will be encrypted
      fix-byte-order-marker.enable = true;
      mixed-line-endings.enable = true;
      trim-trailing-whitespace.enable = true;
      destroyed-symlinks = {
        enable = true;
        name = "destroyed-symlinks";
        description = "detects symlinks which are changed to regular files with a content of a path which that symlink was pointing to.";
        package = inputs.pre-commit-hooks.checks.${system}.pre-commit-hooks;
        entry = "${inputs.pre-commit-hooks.checks.${system}.pre-commit-hooks}/bin/destroyed-symlinks";
        types = [ "symlink" ];
      };

      # nix
      nixfmt-rfc-style.enable = true;
      deadnix = {
        enable = true;
        settings = {
          noLambdaArg = true;
        };
      };
      # statix.enable = true;

      # shellscripts
      shfmt.enable = true;
      shellcheck.enable = true;

      # python
      ruff.enable = true;

      # rust
      rustfmt.enable = true;
      clippy.enable = true;
      cargo-check.enable = true;

      end-of-file-fixer.enable = true;

      git-crypt-check = {
        enable = true;
        name = "git-crypt encryption check";
        entry = "${./git-crypt-check.sh}";
        files = ".*"; # or whatever pattern matches your encrypted files
        language = "script";
        #pass_on_error = false;
      };
    };
  };
}
