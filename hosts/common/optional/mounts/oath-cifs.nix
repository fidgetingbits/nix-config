# FIXME(mount): This should be made into a generic function to use for oath, onus
{
  inputs,
  config,
  pkgs,
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
  mountFolder = "//oath.${config.hostSpec.domain}/shared";
  hasPerNetworkServices = lib.hasAttr "per-network-services" config.services;
  optionsPrefix = lib.optionalString (
    hasPerNetworkServices && config.services.per-network-services.enable
  ) "noauto,";
in
{
  sops.secrets = {
    "cifs/oath" = {
      sopsFile = "${sopsFolder}/shared.yaml";
      owner = config.users.users.${config.hostSpec.username}.name;
      inherit (config.users.users.${config.hostSpec.username}) group;
    };
  };
  systemd.tmpfiles.rules =
    let
      user = config.users.users.${config.hostSpec.username}.name;
      group = config.users.users.${config.hostSpec.username}.group;
    in
    # https://www.man7.org/linux/man-pages/man5/tmpfiles.d.5.html
    [ "d ${homeDirectory}/mount/oath/ 0750 ${user} ${group} -" ];

  fileSystems."/home/${config.hostSpec.username}/mount/oath" = {
    # fileSystems."/mnt/oath" = {
    device = mountFolder;
    fsType = "cifs";
    options = [
      # https://www.freedesktop.org/software/systemd/man/latest/systemd.mount.html
      (optionsPrefix + "nofail,_netdev")
      "uid=${config.hostSpec.username},gid=users,dir_mode=0750,file_mode=0750"
      "vers=3.0,credentials=${config.sops.secrets."cifs/oath".path}"
    ];
  };
  services = lib.mkIf (hasPerNetworkServices && config.services.per-network-services.enable) {
    per-network-services.trustedNetworkMounts = [ mountFolder ];
  };
}
