{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:

let
  pubKeys = lib.filesystem.listFilesRecursive (
    lib.custom.relativeToRoot "hosts/common/users/primary/keys/yubikeys/"
  );
  hostSpec = config.hostSpec;
in
{
  users.users.${hostSpec.username} = {
    name = hostSpec.username;
    shell = pkgs.zsh; # Default Shell

    # These get placed into /etc/ssh/authorized_keys.d/<name> on nixos
    openssh.authorizedKeys.keys = lib.lists.forEach pubKeys (key: builtins.readFile key);
  };

  # No matter what environment we are in we want these tools for root, and the user(s)
  programs.zsh.enable = true;

  environment.systemPackages = [
    pkgs.just
    pkgs.rsync
  ];
}
// lib.optionalAttrs (inputs ? "home-manager") {
  home-manager = {
    extraSpecialArgs = {
      inherit pkgs inputs;
      hostSpec = config.hostSpec;
    };
    users.${hostSpec.username}.imports = lib.flatten (
      lib.optional (!hostSpec.isMinimal) [
        (
          { config, ... }:
          import (lib.custom.relativeToRoot "home/${hostSpec.username}/${hostSpec.hostName}.nix") {
            inherit
              pkgs
              inputs
              config
              lib
              hostSpec
              ;
          }
        )
      ]
    );
  };
}
