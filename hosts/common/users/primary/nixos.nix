{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  hostSpec = config.hostSpec;
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
  sopsHashedPasswordFile = lib.optionalString (
    !config.hostSpec.isMinimal
  ) config.sops.secrets."passwords/${hostSpec.username}".path;
in
{
  # Decrypt password to /run/secrets-for-users/ so it can be used to create the user
  users.mutableUsers = false; # Required for password to be set via sops during system activation!
  users.users.${hostSpec.username} = {
    home = "/home/${hostSpec.username}";
    isNormalUser = true;
    hashedPasswordFile = sopsHashedPasswordFile; # Blank if sops isn't working
    extraGroups = lib.flatten [
      "wheel"
      (ifTheyExist [
        "audio"
        "video"
        "docker"
        "git"
        "networkmanager"
      ])
    ];
  };

  # Persist entire /home for now
  environment = lib.optionalAttrs config.system.impermanence.enable {
    persistence = {
      "${hostSpec.persistFolder}".directories = [
        {
          directory = hostSpec.home;
          user = hostSpec.username;
          group = config.users.users.${hostSpec.username}.group;
          mode = "u=rwx,g=,o=";
        }
      ];
    };
  };
  programs.git.enable = true;

  # root's ssh key are mainly used for remote deployment
  users.users.root = {
    shell = pkgs.zsh;
    hashedPasswordFile = config.users.users.${hostSpec.username}.hashedPasswordFile;
    hashedPassword = lib.mkForce config.users.users.${hostSpec.username}.hashedPassword;
    openssh.authorizedKeys.keys = config.users.users.${hostSpec.username}.openssh.authorizedKeys.keys;
  };
}
// lib.optionalAttrs (inputs ? "home-manager") {

  # Setup p10k.zsh for root
  home-manager.users.root = lib.optionalAttrs (!hostSpec.isMinimal) {
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

}
