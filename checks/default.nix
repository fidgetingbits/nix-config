{
  inputs,
  system,
  pkgs,
  lib,
  ...
}:
{
  bats-test =
    pkgs.runCommand "bats-test"
      {
        src = ../.;
        buildInputs = lib.attrValues { inherit (pkgs) bats yq-go inetutils; };
      }
      ''
        cd $src
        bats tests
        touch $out
      '';

  pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
    src = ./.;
    default_stages = [ "pre-commit" ];
    # NOTE: Hooks are run in alphabetical order
    hooks = lib.recursiveUpdate inputs.introdus.lib.preCommitHooks {
      # Ensure this runs first
      aaa-check-flake-lock = {
        # NOTE: This is a hack because of a pre-commit bug interaction with my per-host flake locking and the need
        # to temporariliy stage flake.lock files. Then the pre-commit hooks run and tries to change something
        # it will try to stash, but stashing will break with the flake.lock stuff, and ultimately it wipes
        # out all unstaged changes for git-tracked files which is maddening
        # You end up with something like this:
        # ```
        # shfmt................................................(no files to check)Skipped
        # trim-trailing-whitespace.................................................Passed
        # [WARNING] Stashed changes conflicted with hook auto-fixes... Rolling back fixes...
        # An unexpected error has occurred: CalledProcessError: command: ('/nix/store/2kfgd447bd1sjzna4q93qxr8680h4182-git-with-svn-2.50.1/libexec/git-core/git', '-c', 'core.autocrlf=false', 'apply', '--whitespace=nowarn', '/home/aa/.cache/pre-commit/patch1759447981-83076')
        # return code: 1
        # stdout: (none)
        # stderr:
        #     error: flake.lock: already exists in working directory
        # Check the log at /home/aa/.cache/pre-commit/pre-commit.log
        # ```
        # Then all your changes are gone. So this check is meant to fail early and indicate the lock needs to be removed.
        # FIXME: Probably could make it to just delete the lock file as an auto-fix...
        enable = true;
        name = "check-flake-lock";
        entry = "${./check-flake-lock.sh}";
        fail_fast = true; # Bail immediately if this fails
        files = ".*";
        language = "script";
        #pass_on_error = false;
      };

      destroyed-symlinks = {
        enable = true;
        name = "destroyed-symlinks";
        description = "detects symlinks which are changed to regular files with a content of a path which that symlink was pointing to.";
        package = inputs.pre-commit-hooks.checks.${system}.pre-commit-hooks;
        entry = "${inputs.pre-commit-hooks.checks.${system}.pre-commit-hooks}/bin/destroyed-symlinks";
        types = [ "symlink" ];
      };

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
