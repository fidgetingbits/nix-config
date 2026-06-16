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
  lan = config.hostSpec.networking.subnets.nlan;
in
{
  ${namespace}.microvms.vms = {
    # Agent vm with tooling, internet access
    nano = {
      user = config.hostSpec.primaryUsername;
      inherit (lan.hosts.nano) ip;
      mac = (lib.head lan.hosts.nano.mac);
      sshPort = 22;
      packages = lib.attrValues {
        inherit (pkgs)
          claude-code
          claude-agent-acp
          codex
          codex-acp
          gemini-cli
          pi-coding-agent

          # zellij
          ;
      };
      inherit hostAuthorizedKeys;
      extraConfig = { };
    };
  };

  # VMs running long agentic tasks shouldn't get restarted on rebuild
  # https://github.com/microvm-nix/microvm.nix/blob/6ad601df/nixos-modules/host/options.nix#L151
  # FIXME: Should integration this into the above somehow
  # microvms.vms.nano.restartIfChanged = lib.mkForce false;
}
