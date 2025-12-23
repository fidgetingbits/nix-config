{
  config,
  lib,
  pkgs,
  secrets,
  ...
}:
{
  programs.ssh = lib.optionalAttrs pkgs.stdenv.isLinux {
    knownHostsFiles =
      lib.optional (!config.hostSpec.isMinimal) (
        pkgs.writeText "custom_private_known_hosts" secrets.networking.ssh.knownHostsFileContents
      )
      ++ lib.optional (config.hostSpec.isWork) (
        pkgs.writeText "custom_work_known_hosts" secrets.work.ssh.knownHostsFileContents or ""
      );
  };
}
