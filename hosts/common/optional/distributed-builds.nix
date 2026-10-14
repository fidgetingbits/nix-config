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
      # I keep maxJobs low to try to more easily split between systems. Sometimes I get a job
      # on oppo that pins all CPU cores, but it's only 1-2 jobs, and so it sits waiting for the
      # next lock on oppo, rather than using oedo. FIXME: Need to see if there is a way to setup
      # smarter job scheduling from nix
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
          maxJobs = 5;
        }
        {
          hostName = "oedo";
          sshUser = "builder";
          sshKey = "/root/.ssh/id_builder";
          publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUREdG9zSHIrMDdJcjQ0Q1FRQ0h3M05RYnlVT0tTaGo1azFZNXdrd1VwelUgYWFAb2Vkbwo=";
          system = pkgs.stdenv.hostPlatform.system;
          supportedFeatures = [
            "nixos-test"
            "big-parallel"
            "kvm"
          ];
          speedFactor = 4; # Favor oppo since oedo runs models
          maxJobs = 2;
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
          Port ${lib.toString config.hostSpec.networking.ports.tcp.ssh}
      '';
      remoteMachines = lib.filter (m: m.hostName != "localhost") config.nix.buildMachines;
      hostNameList = map (machine: machine.hostName) remoteMachines;
    in
    lib.concatStringsSep "\n" (map genHostEntry hostNameList);
}
