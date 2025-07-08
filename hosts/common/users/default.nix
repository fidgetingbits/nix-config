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
  #users.users.${hostSpec.username} = {
  #  name = hostSpec.username;
  #  shell = pkgs.zsh; # Default Shell
  #
  #  # These get placed into /etc/ssh/authorized_keys.d/<name> on nixos
  #  openssh.authorizedKeys.keys = lib.lists.forEach pubKeys (key: builtins.readFile key);
  #};

  users.users = map (user: {
    name = user;
    shell = pkgs.zsh; # Default Shell
    openssh.authorizedKeys.keys = lib.lists.forEach pubKeys (key: builtins.readFile key);

  }) config.hostSpec.users;

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
    users = (
      map (user: {
        user.imports = lib.flatten (
          # FIXME: Can't this move to the lib.optionalAttrs check above?
          lib.optional (!hostSpec.isMinimal) [
            (
              { config, ... }:
              import (lib.custom.relativeToRoot "home/${user}/${hostSpec.hostName}.nix") {
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
      }) config.hostSpec.users
    );
  };
}
