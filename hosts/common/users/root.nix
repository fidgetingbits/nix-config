{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  hostSpec = config.hostSpec;
in
{
  users.users.root = {
    shell = pkgs.zsh;
    hashedPasswordFile = config.users.users.${hostSpec.username}.hashedPasswordFile;
    hashedPassword = lib.mkForce config.users.users.${hostSpec.username}.hashedPassword;
    # root's ssh key are mainly used for remote deployment
    openssh.authorizedKeys.keys = config.users.users.${hostSpec.username}.openssh.authorizedKeys.keys;
  };
}
// lib.optionalAttrs (inputs ? "home-manager" && (!hostSpec.isMinimal)) {
  home-manager = {
    users.root = {
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
  };
}
