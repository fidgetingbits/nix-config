{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  environment.systemPackages = lib.attrValues { inherit (pkgs) s3fs; };
  fileSystems."s3fs" = {
    # trim tailing newline or the system will crash :/
    device = inputs.nix-secrets.work.mounts.s3fs.path;
    mountPoint = "${config.hostSpec.home}/mount/s3";
    fsType = "fuse./run/current-system/sw/bin/s3fs";
    noCheck = true;
    options = [
      "noauto"
      "_netdev"
      "rw"
      "allow_other"
      "url=${inputs.nix-secrets.work.mounts.s3fs.url}"
      "use_path_request_style"
      # FIXME: If this defaults to a using .aws/credentials, then we can use that instead of the passwd_file
      "passwd_file=${config.hostSpec.home}/.aws/s3_access_key"
    ];
  };
}
