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
          hostName = "oedo";
          sshUser = "builder";
          sshKey = "/root/.ssh/id_builder";
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
