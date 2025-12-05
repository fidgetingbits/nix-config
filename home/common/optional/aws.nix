{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  sopsFolder = (builtins.toString inputs.nix-secrets) + "/sops";
in
{
  home.packages = lib.attrValues { inherit (pkgs) awscli eksctl kubectl; };

  sops = {
    secrets = {
      "cloud/aws_credentials" = {
        path = "${config.home.homeDirectory}/.aws/credentials";
        sopsFile = "${sopsFolder}/work.yaml";
      };
    };
  };
}
