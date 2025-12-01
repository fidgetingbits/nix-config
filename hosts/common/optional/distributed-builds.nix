{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  nix.distributedBuilds = true;
  nix.settings = {
    builders-use-substitutes = true;
    fallback = true;
    connect-timeout = 5;
  };

  nix.buildMachines =
    let
      buildMachines = [
        {
          hostName = "oppo";
          sshUser = "builder";
          sshKey = "/root/.ssh/id_builder";
          publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUh2ZkIwLzNQdTZ5T0NhVG9uWXVQRGhiYW5mZG5GZ1VMOWY5TFM1cGdvNkggYWFAb3Bwbwo=";
          system = pkgs.stdenv.hostPlatform.system;
          supportedFeatures = [
            "nixos-test"
            "big-parallel"
            "kvm"
          ];
          speedFactor = 5;
          maxJobs = 32;
        }
        {
          hostName = "oedo-wifi";
          sshUser = "builder";
          sshKey = "/root/.ssh/id_builder";
          publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUREdG9zSHIrMDdJcjQ0Q1FRQ0h3M05RYnlVT0tTaGo1azFZNXdrd1VwelUgYWFAb2Vkbwo=";
          system = pkgs.stdenv.hostPlatform.system;
          supportedFeatures = [
            "nixos-test"
            "big-parallel"
            "kvm"
          ];
          speedFactor = 5;
          maxJobs = 32;
        }
        # Seems slower than it's worth
        # {
        #   hostName = "ooze";
        #   sshUser = "builder";
        #   sshKey = "/root/.ssh/id_builder";
        #   publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUk4SU92SHVwTXB4M3AxRFhDWmRaVVhuYnp1bDZhQ0liYWd1dCtxNCt5dUQgYWFAb296ZQo=";
        #   system = pkgs.stdenv.hostPlatform.system;
        #   supportedFeatures = [
        #     "nixos-test"
        #     "big-parallel"
        #     "kvm"
        #   ];
        #   speedFactor = 2;
        #   maxJobs = 8;
        # }
      ];
    in
    lib.filter (m: m.hostName != config.networking.hostName) buildMachines;

  sops.secrets = {
    "keys/ssh/builder" = {
      owner = "root";
      path = "/root/.ssh/id_builder";
    };
  };
}
// lib.optionalAttrs (inputs ? "home-manager") {
  home-manager.users.root.home.file.".ssh/config".text =
    let
      genHostEntry = hostName: ''
        Host ${hostName}
          HostName ${hostName}.${config.hostSpec.domain}
          Port ${builtins.toString config.hostSpec.networking.ports.tcp.ssh}
      '';
      remoteMachines = lib.filter (m: m.hostName != "localhost") config.nix.buildMachines;
      hostNameList = map (machine: machine.hostName) remoteMachines;
    in
    builtins.concatStringsSep "\n" (map genHostEntry hostNameList);
}
