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

  nix.buildMachines = [
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
      speedFactor = 2;
      maxJobs = 32;
    }
  ];

  sops.secrets = {
    "keys/ssh/builder" = {
      owner = "root";
      path = "/root/.ssh/id_builder";
    };
  };
}
// lib.optionalAttrs (inputs ? "home-manager") {

  home-manager.users.root.home.file.".ssh/config".text = ''
    Host oppo
      HostName oppo.${config.hostSpec.domain}
      Port ${builtins.toString config.hostSpec.networking.ports.tcp.ssh}
  '';
}
