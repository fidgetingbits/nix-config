{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.cifs-mounts;
  homeDirectory =
    if pkgs.stdenv.isLinux then
      "/home/${config.hostSpec.username}"
    else
      "/Users/${config.hostSpec.username}";
  cfgPerNetworkServices = config.${namespace}.services.per-network-services;
  optionsPrefix = lib.optionalString cfgPerNetworkServices.enable "noauto,";
  osConfig = config;
in
{
  options.${namespace}.cifs-mounts = {
    enable = lib.mkEnableOption "CIFS-based mounts for systems";
    sopsFile = lib.mkOption {
      type = lib.types.path;
      default = config.sops.defaultSopsFile;
      description = "SOPS yaml file containing the passwords for the CIFS mounts";
    };

    mounts = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule (
          { config, ... }:
          {
            options = rec {
              name = lib.mkOption {
                type = lib.types.str;
                example = "server";
                description = "Subdomain of system to mount the folder from";
              };
              url = lib.mkOption {
                type = lib.types.str;
                default = "//${config.name}.${osConfig.hostSpec.domain}/shared";
                example = "//server.example.com/shared";
                description = "CIFS url to mount";
              };
              folder = lib.mkOption {
                type = lib.types.str;
                default = "${homeDirectory}/mount/${config.name}";
                example = "/home/foo/mount/server";
                description = "Folder to mount to";
              };
              user = lib.mkOption {
                type = lib.types.str;
                default = osConfig.users.users.${osConfig.hostSpec.primaryUsername}.name;
                example = "user";
                description = "User to mount as";
              };

              group = lib.mkOption {
                type = lib.types.str;
                default = osConfig.users.users.${osConfig.hostSpec.primaryUsername}.group;
                example = "group";
                description = "Group to mount as";
              };
            };

          }
        )
      );
      default = [ ];
    };
  };

  config = lib.mkIf cfg.enable (rec {
    sops.secrets =
      cfg.mounts
      |> lib.map (mount: {
        "cifs/${mount.name}" = {
          inherit (cfg) sopsFile;
          inherit (mount) group;
          owner = mount.user;
        };
      })
      |> lib.mergeAttrsList;

    systemd.tmpfiles.rules =
      cfg.mounts
      |> lib.map (
        mount:
        # https://www.man7.org/linux/man-pages/man5/tmpfiles.d.5.html
        "d ${mount.folder} 0750 ${mount.user} ${mount.group} -"
      );

    fileSystems =
      cfg.mounts
      |> lib.map (mount: {
        ${mount.folder} = {
          device = mount.url;
          fsType = "cifs";
          options = [
            # https://www.freedesktop.org/software/systemd/man/latest/systemd.mount.html
            (optionsPrefix + "nofail,_netdev")
            "uid=${mount.user},gid=${mount.group},dir_mode=0750,file_mode=0750"
            "vers=3.0,credentials=${osConfig.sops.secrets."cifs/${mount.name}".path}"
          ];
        };
      })
      |> lib.mergeAttrsList;

    ${namespace}.services = lib.mkIf cfgPerNetworkServices.enable {
      per-network-services.trustedNetworkMounts = lib.map (mount: mount.url) cfg.mounts;
    };
  });
}
