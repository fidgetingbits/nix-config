# see home/[user]/common/optional/sops.nix for home/user level
{
  lib,
  inputs,
  pkgs,
  config,
  ...
}:
let
  sopsFolder = (builtins.toString inputs.nix-secrets) + "/sops";
in
{
  sops = {
    defaultSopsFile = "${sopsFolder}/${config.hostSpec.hostName}.yaml";
    validateSopsFiles = false;
    age = {
      # automatically import host SSH keys as age keys
      sshKeyPaths = [ "${config.hostSpec.persistFolder}/etc/ssh/ssh_host_ed25519_key" ];
    };
    # secrets will be output to /run/secrets
    # secrets required for user creation are handled in respective ./users/<username>.nix files
    # because they will be output to /run/secrets-for-users and only when the user is assigned to a host.
  };

  # For home-manager a separate age key is used to decrypt secrets and must be placed onto the host. This is because
  # the user doesn't have read permission for the ssh service private key. However, we can bootstrap the age key from
  # the secrets decrypted by the host key, which allows home-manager secrets to work without manually copying over
  # the age key.
  sops.secrets =
    let
      linuxEntries = (
        lib.mergeAttrsList (
          map (user: {
            # FIXME: This might end up not being linux-specific depending on nix-darwin sops PR
            "passwords/${user}" = {
              sopsFile = "${sopsFolder}/shared.yaml";
              neededForUsers = true;
            };
          }) config.hostSpec.users
        )
      );
    in
    lib.mkMerge [
      {
        # FIXME: We may need an age key per user technically?
        "keys/age" = {
          owner = config.users.users.${config.hostSpec.primaryUsername}.name;
          group =
            if pkgs.stdenv.isLinux then
              config.users.users.${config.hostSpec.primaryUsername}.group
            else
              "staff";
          # See later activation script for folder permission sanitization
          path = "${config.hostSpec.home}/.config/sops/age/keys.txt";
        };
      }

      (lib.mkIf (config.hostSpec.isLocal || config.hostSpec.useAtticCache) {
        # NOTE: These two entries are duplicated in home sops as well, and here because nix.nix can't

        # directly check for sops usage due to recursion in some situations
        # formatted as extra-access-tokens = github.com=<PAT token>
        "tokens/nix-access-tokens" = {
          sopsFile = "${sopsFolder}/olan.yaml";
        };
        "passwords/netrc" = {
          sopsFile = "${sopsFolder}/olan.yaml";
        };
      })

      (lib.mkIf config.services.backup.enable {
        "passwords/borg" = {
          owner = "root";
          group = if pkgs.stdenv.isLinux then "root" else "wheel";
          mode = "0600";
          path = "/etc/borg/passphrase";
        };
      })
      (lib.mkIf pkgs.stdenv.isLinux linuxEntries)
    ];

  # The containing folders are created as root, and if this is the first ~/.config/ entry,
  # the ownership is busted and home-manager can't target because it can't write into .config...
  # FIXME: We might not need this depending on how https://github.com/Mic92/sops-nix/issues/381 is fixed
  # FIXME: Try to replace this with. Need to have one entry per folder
  # https://discourse.nixos.org/t/is-it-possible-to-declare-a-directory-creation-in-the-nixos-configuration/27846/6
  # systemd.tmpfiles.rules = [
  # "d ${homeDirectory}/.config/sops/age 0750 user group -"
  # ];
  system.activationScripts.sopsSetAgeKeyOwnership =
    let
      ageFolder = "${config.hostSpec.home}/.config/sops/age";
      user = config.users.users.${config.hostSpec.username}.name;
      group =
        if pkgs.stdenv.isLinux then config.users.users.${config.hostSpec.username}.group else "staff";
    in
    ''
      mkdir -p ${ageFolder} || true
      chown ${user}:${group} ${config.hostSpec.home}/.config
    '';
}
