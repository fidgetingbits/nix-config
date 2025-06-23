{ pkgs, ... }:
let
  # FIXME: I currently get the following warnings:
  # svn: warning: cannot set LC_CTYPE locale
  # svn: warning: environment variable LANG is en_US.UTF-8
  # svn: warning: please check that your locale name is correct
  copy-github-subfolder = pkgs.writeShellApplication {
    name = "copy-github-subfolder";
    runtimeInputs = [ pkgs.subversion ];
    text = builtins.readFile ./copy-github-subfolder.sh;
  };
  linktree = pkgs.writeShellApplication {
    name = "linktree";
    runtimeInputs = [ ];
    text = builtins.readFile ./linktree.sh;
  };
  build-cursorless-pr-bundle = pkgs.writeShellApplication {
    name = "build-cursorless-pr-bundle";
    runtimeInputs = builtins.attrValues { inherit (pkgs) git direnv; };
    text = builtins.readFile ./build-cursorless-pr-bundle.sh;
  };
  build-command-server-pr-bundle = pkgs.writeShellApplication {
    name = "build-command-server-pr-bundle";
    runtimeInputs = builtins.attrValues { inherit (pkgs) git direnv; };
    text = builtins.readFile ./build-command-server-pr-bundle.sh;
  };
  calculate-flac-hours = pkgs.writeShellApplication {
    name = "calculate-flac-hours";
    runtimeInputs = builtins.attrValues { inherit (pkgs) sox; };
    text = builtins.readFile ./calculate-flac-hours.sh;
  };
  update-core-repos = pkgs.writeShellApplication {
    name = "update-core-repos";
    runtimeInputs = builtins.attrValues { inherit (pkgs) git; };
    text = builtins.readFile ./update-core-repos.sh;
  };
  dockertags = pkgs.writeShellApplication {
    name = "dockertags";
    runtimeInputs = builtins.attrValues { inherit (pkgs) wget jq; };
    text = builtins.readFile ./dockertags.sh;
  };
  nixvim-plugins-dir = pkgs.writeShellApplication {
    name = "nixvim-plugins-dir";
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ./nixvim-plugins-dir.sh;
  };
  populate-cursorless-neovim-node = pkgs.writeShellApplication {
    name = "populate-cursorless-neovim-node";
    runtimeInputs = builtins.attrValues { inherit (pkgs) git corepack; };
    text = builtins.readFile ./populate-cursorless-neovim-node.sh;
  };
  neovim-reload-all = pkgs.writeShellApplication {
    name = "neovim-reload-all";
    runtimeInputs = [ pkgs.neovim ];
    text = builtins.readFile ./neovim-reload-all.sh;
  };
  generate-private-git-repos = pkgs.writeShellApplication {
    name = "generate-private-git-repos";
    runtimeInputs = builtins.attrValues {
      inherit (pkgs)
        git
        jq
        gawk
        gh
        glab
        ;
    };
    text = builtins.readFile ./generate-private-git-repos.sh;
  };
  git-submodules-ignoreuntracked = pkgs.writeShellApplication {
    name = "git-submodules-ignore-untracked";
    runtimeInputs = builtins.attrValues { inherit (pkgs) git gnugrep gawk; };
    text = builtins.readFile ./git-submodules-ignore-untracked.sh;
  };
in
{
  home.packages = [
    copy-github-subfolder
    linktree
    build-cursorless-pr-bundle
    build-command-server-pr-bundle
    update-core-repos
    dockertags
    calculate-flac-hours
    nixvim-plugins-dir
    populate-cursorless-neovim-node
    neovim-reload-all
    generate-private-git-repos
    git-submodules-ignoreuntracked
  ];
}
