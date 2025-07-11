{
  inputs,
  pkgs,
  config,
  lib,
  isDarwin,
  ...
}:

let
  platform = if isDarwin then "darwin" else "nixos";
  hostSpec = config.hostSpec;

  # List of yubikey public keys for the primary user
  pubKeys = lib.filesystem.listFilesRecursive (
    lib.custom.relativeToRoot "hosts/common/users/${hostSpec.primaryUsername}/keys/yubikeys/"
  );
  # IMPORTANT: primary user keys are used for authorized_keys to all users. Change below if
  # you don't want this!
  primaryUserPubKeys = lib.lists.forEach pubKeys (key: builtins.readFile key);
in
{
  imports = lib.optional isDarwin [ "root.nix" ];

  # No matter what environment we are in we want these tools for root, and the user(s)
  programs.zsh.enable = true;
  programs.git.enable = true;
  environment = {
    systemPackages = [
      pkgs.just
      pkgs.rsync
    ];
  };

  # Import all non-root users
  users =
    {
      users = (
        lib.mergeAttrsList
          # FIXME: For isMinimal we can likely just filter out primaryUsername only?
          (
            map (user: {
              "${user}" =
                let
                  sopsHashedPasswordFile = lib.optionalString (
                    !config.hostSpec.isMinimal
                  ) config.sops.secrets."passwords/${user}".path;
                  platformPath = lib.custom.relativeToRoot "hosts/common/users/${user}/${platform}.nix";
                in
                {
                  name = user;
                  shell = pkgs.zsh; # Default Shell
                  # IMPORTANT: Gives yubikey-based ssh access of primary user to all other users! Change if needed
                  openssh.authorizedKeys.keys = primaryUserPubKeys;
                  home = if isDarwin then "/Users/${user}" else "/home/${user}";
                  # Decrypt password to /run/secrets-for-users/ so it can be used to create the user
                  hashedPasswordFile = sopsHashedPasswordFile; # Blank if sops isn't working
                }
                # Add in platform-specific user values if they exist
                // lib.optionalAttrs (lib.pathExists platformPath) (
                  import platformPath {
                    inherit config lib;
                  }
                );
            }) config.hostSpec.users
          )
      );
    }
    //
    # Extra platform-specific options
    lib.optionalAttrs (!isDarwin) {
      mutableUsers = false; # Required for password to be set via sops during system activation!
    };
}
// lib.optionalAttrs (inputs ? "home-manager") {
  home-manager =
    let
      importFileIfPresent =
        path:
        lib.optionalAttrs (lib.pathExists (lib.custom.relativeToRoot path)) (
          import (lib.custom.relativeToRoot "${path}") {
            inherit
              pkgs
              inputs
              config
              lib
              hostSpec
              ;
          }
        );
    in
    {
      extraSpecialArgs = {
        inherit pkgs inputs;
        hostSpec = config.hostSpec;
      };
      # FIXME: Common for all users (will include root too!)
      #sharedModules = map (module: (import module)) (
      #  map lib.custom.relativeToRoot ([
      #    "home/common/core"
      #    (if isDarwin then "home/common/core/darwin.nix" else "home/common/core/nixos.nix")
      #  ])
      #);
      # Add all non-root users to home-manager
      users = lib.mergeAttrsList (
        map (user: {
          "${user}".imports = lib.flatten [
            (lib.optional (!hostSpec.isMinimal) (
              map (importFileIfPresent) [
                "home/${user}/${hostSpec.hostName}.nix"
                "home/${user}/common/${platform}.nix"
              ]
            ))
            # Static module with common values avoids duplicate file per user
            (
              { ... }:
              {
                home = {
                  homeDirectory = if isDarwin then "/Users/${user}" else "/home/${user}";
                  username = "${user}";
                };
              }
            )
          ];
        }) config.hostSpec.users
      );
    };
}
