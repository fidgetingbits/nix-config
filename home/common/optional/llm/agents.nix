# NOTE: This is used by microvms, so don't add anything too wacko
{
  pkgs,
  lib,
  inputs,
  osConfig,
  ...
}:
# Some example config via nix here
# https://github.com/codgician/serenitea-pot/blob/1e24dbe92e4226b014238ec32d67a8eaf736f5e6/hm-modules/codgi/generic/oh-my-pi/profiles/default.nix#L36
let
  yamlFormat = pkgs.formats.yaml { };
  ompConfig = {
    skills = {
      enabled = true;
      enableSkillCommands = true;
      enableCodexUser = false;
      enableClaudeUser = false;
      enableClaudeProject = false;
      customDirectories = [
        # Dynamic skills per microvm
        "/home/aa/dev/ai/shared/${osConfig.networking.hostName}/skills"
        # Dynamic skills shared across all locally hosted VMs
        "/home/aa/dev/ai/vms-shared//skills"
        # Declarative private skills
        "${inputs.fidgeting-skills}"
      ];
    };
  };
  ompConfigFile = yamlFormat.generate "omp-overlay.yaml" ompConfig;
  ompWrapped = inputs.wrappers.lib.wrapPackage (
    {
      ...
    }:
    {
      inherit pkgs;
      package = pkgs.omp;
      flags = {
        "--config" = "${ompConfigFile}";
      };
    }
  );
in
{
  home = {
    packages = [
      ompWrapped
    ]
    ++ (lib.attrValues {
      inherit (pkgs)
        claude-code
        claude-agent-acp
        codex
        codex-acp
        crush
        gemini-cli
        pi-coding-agent
        ;
    });
  };
}
