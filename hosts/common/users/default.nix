{
  inputs,
  pkgs,
  config,
  lib,
  isDarwin,
  ...
}:

let
  hostSpec = config.hostSpec;
  pubKeys = lib.filesystem.listFilesRecursive (
    lib.custom.relativeToRoot "hosts/common/users/${hostSpec.primaryUsername}/keys/yubikeys/"
  );
  platform = if isDarwin then "darwin" else "nixos";
in
{
  imports = lib.optional isDarwin [ "root.nix" ];
  users =
    {
      users = (
        # FIXME: This likely no longer needs flatten or mergeAttrsList
        lib.mergeAttrsList (
          lib.flatten [
            # Import all non-root users
            (map (user: {
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
                  openssh.authorizedKeys.keys = lib.lists.forEach pubKeys (key: builtins.readFile key);
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
            }) config.hostSpec.users)
          ]
        )
      );
    }
    //
    # Extra platform-specifc options (break out into files if they end up being more
    lib.optionalAttrs (!isDarwin) {
      mutableUsers = false; # Required for password to be set via sops during system activation!
    };

  # No matter what environment we are in we want these tools for root, and the user(s)
  programs.zsh.enable = true;
  programs.git.enable = true;
  environment = {
    systemPackages = [
      pkgs.just
      pkgs.rsync
    ];
  };
}
// lib.optionalAttrs (inputs ? "home-manager") {
  home-manager = {
    extraSpecialArgs = {
      inherit pkgs inputs;
      hostSpec = config.hostSpec;
    };
    # Common for all users (will include root too!)
    #sharedModules = map (module: (import module)) (
    #  map lib.custom.relativeToRoot ([
    #    "home/common/core"
    #    (if isDarwin then "home/common/core/darwin.nix" else "home/common/core/nixos.nix")
    #  ])
    #);
    # FIXME: Add sharedModules with all the common cross-user stuff
    # Add all non-root users to home-manager
    # FIXME: Can likely remove merge and flatten now
    users = lib.mergeAttrsList (
      lib.flatten [
        (map (user: {
          "${user}".imports = lib.flatten (
            (lib.optional (!hostSpec.isMinimal) (
              map
                (
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
                  )
                )
                [
                  "home/${user}/${hostSpec.hostName}.nix"
                  "home/${user}/common/${platform}.nix"
                ]
            ))
            # Add in some common values so we don't have to have a file per user
            ++ [
              (
                { ... }:
                {
                  home = {
                    homeDirectory = if isDarwin then "/Users/${user}" else "/home/${user}";
                    username = "${user}";
                  };
                }
              )
            ]
          );
        }) config.hostSpec.users)
      ]
    );
  };
}
