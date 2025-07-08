{
  inputs,
  pkgs,
  config,
  lib,
  isDarwin,
  ...
}:

let
  pubKeys = lib.filesystem.listFilesRecursive (
    lib.custom.relativeToRoot "hosts/common/users/aa/keys/yubikeys/"
  );
  hostSpec = config.hostSpec;
  platform = if isDarwin then "darwin" else "nixos";
in
{
  users =
    {
      users = (
        lib.mergeAttrsList (
          lib.flatten [
            # Import all non-root users
            (map (user: {
              "${user}" =
                {
                  name = user;
                  shell = pkgs.zsh; # Default Shell
                  openssh.authorizedKeys.keys = lib.lists.forEach pubKeys (key: builtins.readFile key);
                  home = if isDarwin then "/Users/${user}" else "/home/${user}";
                }
                # Add in platform-specific user values
                // (import (lib.custom.relativeToRoot "hosts/common/users/${user}/${platform}.nix") {
                  inherit config lib;
                });
            }) config.hostSpec.users)
            # Define root user (FIXME: Maybe conditionally import this and do it in nixos.nix?
            (lib.optionalAttrs (!isDarwin) {
              root = {
                shell = pkgs.zsh;
                hashedPasswordFile = config.users.users.${hostSpec.username}.hashedPasswordFile;
                hashedPassword = lib.mkForce config.users.users.${hostSpec.username}.hashedPassword;
                # root's ssh key are mainly used for remote deployment
                openssh.authorizedKeys.keys = config.users.users.${hostSpec.username}.openssh.authorizedKeys.keys;
              };
            })
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
  environment =
    {
      systemPackages = [
        pkgs.just
        pkgs.rsync
      ];
    }
    // lib.optionalAttrs config.system.impermanence.enable {
      # Persist entire /home for now
      persistence = {
        "${config.hostSpec.persistFolder}".directories = map (user: {
          # This should iterate over users.users and use their home/user/group instead
          directory = config.users.users."${user}".home;
          inherit user;
          group = config.users.users."${user}".group;
          mode = "u=rwx,g=,o=";
        }) config.hostSpec.users;
      };
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
    users = lib.mergeAttrsList (
      lib.flatten [
        (map (user: {
          "${user}".imports = lib.flatten (
            lib.optional (!hostSpec.isMinimal) (
              map
                (
                  path:
                  (import (lib.custom.relativeToRoot "${path}") {
                    inherit
                      pkgs
                      inputs
                      config
                      lib
                      # FIXME: We should modify hostSpec here to change the username and home to match whatever
                      # user we are injecting, this way we don't need to set it in the individual files
                      hostSpec
                      ;
                  })
                )
                [
                  "home/${user}/${hostSpec.hostName}.nix"
                  "home/${user}/common/${platform}.nix"
                ]
            )

          );
        }) config.hostSpec.users)
        # Add root user (FIXME: Probably move this into nixos.nix together with above one)
        (lib.optionalAttrs (!isDarwin) {
          # FIXME: This check can be combined with the above later
          root = lib.optionalAttrs (!hostSpec.isMinimal) {
            home.stateVersion = "23.05"; # Avoid error
            programs.zsh = {
              enable = true;
              plugins = [
                {
                  name = "powerlevel10k-config";
                  src = lib.custom.relativeToRoot "home/common/core/zsh/p10k";
                  file = "p10k.zsh";
                }
              ];
            };
          };
        })
      ]
    );
  };
}
