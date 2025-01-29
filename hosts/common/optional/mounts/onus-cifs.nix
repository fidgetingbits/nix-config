{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:
let
  sopsFolder = (builtins.toString inputs.nix-secrets) + "/sops";
  homeDirectory =
    if pkgs.stdenv.isLinux then
      "/home/${config.hostSpec.username}"
    else
      "/Users/${config.hostSpec.username}";
  mountFolder = "//onus.${config.hostSpec.domain}/shared";
  optionsPrefix = lib.optionalString config.services.per-network-services.enable "noauto,";
in
{
  sops.secrets = {
    "cifs/onus" = {
      sopsFile = "${sopsFolder}/shared.yaml";
      owner = config.users.users.${config.hostSpec.username}.name;
      inherit (config.users.users.${config.hostSpec.username}) group;
    };
  };
  # FIXME(mount): This and oath-cifs are very similar, could likely be turned into a function
  systemd.tmpfiles.rules =
    let
      user = config.users.users.${config.hostSpec.username}.name;
      group = config.users.users.${config.hostSpec.username}.group;
    in
    # https://www.man7.org/linux/man-pages/man5/tmpfiles.d.5.html
    [ "d ${homeDirectory}/mount/onus/ 0750 ${user} ${group} -" ];

  fileSystems."/home/${config.hostSpec.username}/mount/onus" = {
    device = mountFolder;
    fsType = "cifs";
    options = [
      # https://www.freedesktop.org/software/systemd/man/latest/systemd.mount.html
      (optionsPrefix + "nofail,_netdev")
      "uid=${config.hostSpec.username},gid=users,dir_mode=0750,file_mode=0750"
      "vers=3.0,credentials=${config.sops.secrets."cifs/onus".path}"
    ];
  };
  services.per-network-services.trustedNetworkMounts = [ mountFolder ];
}
