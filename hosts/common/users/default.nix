{
  inputs,
  pkgs,
  config,
  lib,
  isDarwin,
  namespace,
  secrets,
  ...
}:

let
  # Generate a list of public key contents to use by ssh
  genPubKeyList =
    user:
    let
      keyPath = (lib.custom.relativeToRoot "hosts/common/users/${user}/keys/");
    in
    if (lib.pathExists keyPath) then
      lib.lists.forEach (lib.filesystem.listFilesRecursive keyPath) (key: lib.readFile key)
    else
      [ ];

  # List of yubikey public keys that will allow auth to any user, across systems
  superPubKeys = genPubKeyList "super";

  platform = if isDarwin then "darwin" else "nixos";
  hostSpec = config.hostSpec;
  monitors = config.monitors;
in
{
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
  users = {
    users =
      (lib.mergeAttrsList
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
                shell = pkgs.zsh;
                # Adds ssh pub key access to the user to the defined user keys AND the super keys
                openssh.authorizedKeys.keys = (genPubKeyList user) ++ superPubKeys;
                home = if isDarwin then "/Users/${user}" else "/home/${user}";
                # Decrypt password to /run/secrets-for-users/ so it can be used to create the user
                hashedPasswordFile = sopsHashedPasswordFile; # Blank if sops isn't working
              }
              # Add in platform-specific user values if they exist
              // lib.optionalAttrs (lib.pathExists platformPath) (
                import platformPath {
                  inherit config lib inputs;
                }
              );
          }) config.hostSpec.users
        )
      )
      // {
        root = {
          shell = pkgs.zsh;
          hashedPasswordFile = config.users.users.${config.hostSpec.primaryUsername}.hashedPasswordFile;
          hashedPassword = lib.mkForce config.users.users.${config.hostSpec.primaryUsername}.hashedPassword;
          # root's ssh key are mainly used for remote deployment
          # FIXME: Do we ever want this to just be super keys and not the users keys?
          openssh.authorizedKeys.keys =
            config.users.users.${config.hostSpec.primaryUsername}.openssh.authorizedKeys.keys;
        };
      };
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
      fullPathIfExists =
        path:
        let
          fullPath = lib.custom.relativeToRoot path;
        in
        lib.optional (lib.pathExists fullPath) fullPath;
    in
    rec {
      extraSpecialArgs = {
        inherit
          pkgs
          inputs
          namespace
          secrets
          ;
      };
      # FIXME: Common for all users (will include root too!)
      # sharedModules = map (module: (import module)) (
      #   map lib.custom.relativeToRoot ([
      #     "home/common/core"
      #     (if isDarwin then "home/common/core/darwin.nix" else "home/common/core/nixos.nix")
      #   ])
      # );

      # Add all non-root users to home-manager
      users =
        (lib.mergeAttrsList (
          map (user: {
            "${user}".imports = lib.flatten [
              (lib.optional (!hostSpec.isMinimal) (
                map (fullPathIfExists) [
                  "home/${user}/${hostSpec.hostName}.nix"
                  "home/${user}/common/"
                  "home/${user}/common/${platform}.nix"
                ]
              ))
              # Static module with common values avoids duplicate file per user
              (
                { ... }:
                {
                  inherit hostSpec monitors; # Bring nixos option values into hm copy
                  home = {
                    stateVersion = "23.05";
                    homeDirectory = if isDarwin then "/Users/${user}" else "/home/${user}";
                    username = "${user}";
                  };
                }
              )
              # sharedModules
            ];
          }) config.hostSpec.users
        ))
        // {
          root = {
            home.stateVersion = "23.05"; # Avoid error
            imports = (
              map lib.custom.relativeToRoot [
                "modules/home/starship.nix"
                "modules/home/p10k"
              ]
            );

            # programs.starship = {
            #   enable = true;
            #   package = pkgs.unstable.starship;
            #   right_divider_str = "  ";
            #   left_divider_str = "  ";
            #   fill_str = "·";
            # };

            programs.zsh = {
              enable = true;
            };
            p10k.enable = true;

          };
        };
    };
}
