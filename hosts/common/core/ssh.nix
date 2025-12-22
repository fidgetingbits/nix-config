{
  config,
  lib,
  pkgs,
  secrets,
  ...
}:
{

  programs.ssh = lib.optionalAttrs pkgs.stdenv.isLinux {
    knownHostsFiles = [
      (pkgs.writeText "custom_known_hosts" ''
        ###
        ## github
        ##
        ## https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
        ##
        ##
        github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
        github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=

        ###
        ## gitlab
        ##
        ## https://docs.gitlab.com/user/gitlab_com/#ssh-known_hosts-entries
        ##
        gitlab.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf
        gitlab.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBFSMqzJeV9rUzU4kWitGjeR4PWSa29SPqJ1fVkhtj3Hw9xjLVXVYrU9QlYWrOLXBpQ6KWjbjTDTdDkoohFzgbEY=

        ###
        ## codeberg
        ##
        ## https://codeberg.org/Codeberg/org/src/branch/main/Imprint.md#user-content-ssh-fingerprints
        ##
        codeberg.org ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBL2pDxWr18SoiDJCGZ5LmxPygTlPu+cCKSkpqkvCyQzl5xmIMeKNdfdBpfbCGDPoZQghePzFZkKJNR/v9Win3Sc=
        codeberg.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIVIC02vnjFyL+I4RHfvIGNtOgJMe769VTF1VR4EB3ZB
      '')
    ]
    ++ lib.optional (!config.hostSpec.isMinimal) (
      pkgs.writeText "custom_private_known_hosts" secrets.networking.ssh.knownHostsFileContents
    )
    ++ lib.optional (config.hostSpec.isWork) (
      pkgs.writeText "custom_work_known_hosts" secrets.work.ssh.knownHostsFileContents or ""
    );
  };
}
