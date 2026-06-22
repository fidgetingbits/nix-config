# microvm-related host configuration for agent vms
{
  lib,
  inputs,
  config,
  vmOpts,
  ...
}:
let
  sopsFolder = (lib.toString inputs.nix-secrets) + "/sops";
in
{
  sops.secrets = {
    "tokens/claude" = {
      sopsFile = "${sopsFolder}/agents.yaml";
      group = "kvm";
      mode = "0440";
    };
  };

  # This service copies secrets directly into a ramfs on the microvm
  # See ./default for why
  systemd.services.microvm-prepare-agent-secrets = {
    description = "Stage SOPS agent secrets for microVM";
    wantedBy = [ "multi-user.target" ];
    after = [ "sops-nix.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    # NOTE: ./default systemd.tmpfiles.rules already handled /run/microvm-secrets/${name} creation
    script =
      let
        name = vmOpts.name;
      in
      # bash
      ''
        cp --remove-destination ${
          config.sops.secrets."tokens/claude".path
        } /run/microvm-secrets/${name}/anthropic_api_key
        chgrp kvm /run/microvm-secrets/${name}/anthropic_api_key
      '';
  };
}
