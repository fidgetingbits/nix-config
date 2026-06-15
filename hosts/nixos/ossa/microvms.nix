{
  config,
  pkgs,
  lib,
  # inputs,
  namespace,
  ...
}:

let
  hostAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBpB8D7hvlBLDbt936OljTdpNcT01pHYqnnZj5rpD+xF aa@ossa"
  ];
  # FIXME: switch this name to just microvm-lan or something
  lan = config.hostSpec.networking.subnets.agent-lan;
in
{
  ${namespace}.microvms.vms = {

    # Agent vm with tooling, internet access
    nano = {
      user = config.hostSpec.primaryUsername;
      inherit (lan.hosts.nano) ip;
      mac = (lib.head lan.hosts.nano.mac);
      sshPort = 22;
      externalSshPort = 11022;
      packages = lib.attrValues {
        inherit (pkgs)
          claude-code
          claude-agent-acp
          codex
          codex-acp
          gemini-cli
          zellij
          # pi
          ;
      };
      inherit hostAuthorizedKeys;
      extraConfig = { };
    };
  };
}
