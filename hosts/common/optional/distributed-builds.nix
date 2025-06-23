{
  pkgs,
  ...
}:
{
  nix.distributedBuilds = true;
  nix.settings.builders-use-substitutes = true;

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
    }
  ];

  sops.secrets = {
    "keys/ssh/builder" = {
      owner = "root";
      path = "/root/.ssh/id_builder";
    };
  };
}
