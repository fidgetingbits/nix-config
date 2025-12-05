{ pkgs, lib, ... }:
let
  # FIXME: I currently get the following warnings:
  # svn: warning: cannot set LC_CTYPE locale
  # svn: warning: environment variable LANG is en_US.UTF-8
  # svn: warning: please check that your locale name is correct
  copy-github-subfolder = pkgs.writeShellApplication {
    name = "copy-github-subfolder";
    runtimeInputs = [ pkgs.subversion ];
    text = lib.readFile ./copy-github-subfolder.sh;
  };
  linktree = pkgs.writeShellApplication {
    name = "linktree";
    runtimeInputs = [ ];
    text = lib.readFile ./linktree.sh;
  };
  build-cursorless-pr-bundle = pkgs.writeShellApplication {
    name = "build-cursorless-pr-bundle";
    runtimeInputs = lib.attrValues { inherit (pkgs) git direnv; };
    text = lib.readFile ./build-cursorless-pr-bundle.sh;
  };
  build-command-server-pr-bundle = pkgs.writeShellApplication {
    name = "build-command-server-pr-bundle";
    runtimeInputs = lib.attrValues { inherit (pkgs) git direnv; };
    text = lib.readFile ./build-command-server-pr-bundle.sh;
  };
  calculate-flac-hours = pkgs.writeShellApplication {
    name = "calculate-flac-hours";
    runtimeInputs = lib.attrValues { inherit (pkgs) sox; };
    text = lib.readFile ./calculate-flac-hours.sh;
  };
  update-core-repos = pkgs.writeShellApplication {
    name = "update-core-repos";
    runtimeInputs = lib.attrValues { inherit (pkgs) git; };
    text = lib.readFile ./update-core-repos.sh;
  };
  dockertags = pkgs.writeShellApplication {
    name = "dockertags";
    runtimeInputs = lib.attrValues { inherit (pkgs) wget jq; };
    text = lib.readFile ./dockertags.sh;
  };
  nixvim-plugins-dir = pkgs.writeShellApplication {
    name = "nixvim-plugins-dir";
    runtimeInputs = [ pkgs.coreutils ];
    text = lib.readFile ./nixvim-plugins-dir.sh;
  };
  populate-cursorless-neovim-node = pkgs.writeShellApplication {
    name = "populate-cursorless-neovim-node";
    runtimeInputs = lib.attrValues { inherit (pkgs) git corepack; };
    text = lib.readFile ./populate-cursorless-neovim-node.sh;
  };
  neovim-reload-all = pkgs.writeShellApplication {
    name = "neovim-reload-all";
    runtimeInputs = [ pkgs.neovim ];
    text = lib.readFile ./neovim-reload-all.sh;
  };
  generate-private-git-repos = pkgs.writeShellApplication {
    name = "generate-private-git-repos";
    runtimeInputs = lib.attrValues {
      inherit (pkgs)
        git
        jq
        gawk
        gh
        glab
        ;
    };
    text = lib.readFile ./generate-private-git-repos.sh;
  };
  git-submodules-ignoreuntracked = pkgs.writeShellApplication {
    name = "git-submodules-ignore-untracked";
    runtimeInputs = lib.attrValues { inherit (pkgs) git gnugrep gawk; };
    text = lib.readFile ./git-submodules-ignore-untracked.sh;
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
